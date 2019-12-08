source('global.R')

header <- dashboardHeader(title="Ivermectin directory")
sidebar <- dashboardSidebar(
  sidebarMenu(
    menuItem(
      text="Directory",
      tabName="directory",
      icon=icon("eye")),
    menuItem(
      text = 'About',
      tabName = 'about',
      icon = icon("cog", lib = "glyphicon"))
  )
)

body <- dashboardBody(
  tags$head(
    tags$link(rel = "stylesheet", type = "text/css", href = "custom.css")
  ),
  tabItems(
    tabItem(
      tabName="directory",
      fluidPage(
        fluidRow(h3('Instructions')),
        fluidRow(column(6,
                        p('Once you have selected people, click below to send them an email'), 
                        uiOutput('ui_send_email'),
                        uiOutput('ui_create_account')),
                 uiOutput('edit_text')),
        fluidRow(DT::dataTableOutput('edit_table'))
      )
    ),
    tabItem(
      tabName = 'about',
      fluidPage(
        fluidRow(
          div(img(src='logo_clear.png', align = "center"), style="text-align: center;"),
          h4('Hosted by ',
             a(href = 'http://databrew.cc',
               target='_blank', 'Databrew'),
             align = 'center'),
          p('Empowering research and analysis through collaborative data science.', align = 'center'),
          div(a(actionButton(inputId = "email", label = "info@databrew.cc", 
                             icon = icon("envelope", lib = "font-awesome")),
                href="mailto:info@databrew.cc",
                align = 'center')), 
          style = 'text-align:center;'
        )
      )
    )
  )
)

# UI
ui <- dashboardPage(header, sidebar, body, skin="blue")

# Server
server <- function(input, output, session) {
  
  # Reactive values
  data <- reactiveValues(user_data = data.frame(),
                         users = users)
  log_in_text <- reactiveVal('')
  email_text <- reactiveVal('')
  email_people <- reactiveVal('')
  logged_in <- reactiveVal(value = FALSE)
  modal_text <- reactiveVal(value = '')
  is_admin <- reactiveVal(value = FALSE)
  
  # observe log in and get data from database
  observeEvent(input$submit, {
    this_user_data <- dbGetQuery(conn = co, 
                                 statement = paste0("SELECT * FROM users WHERE email='", input$user, "'"))
    data$user_data <- this_user_data
    is_admin(this_user_data$admin)
    addy <- is_admin()
    message('this user - ', this_user_data$email, ' - ',
            ifelse(addy, 'is an admin', 'is not an admin'))
    li <- logged_in()
    if(li){removeModal()}
  })
  
  # Log in modal
  showModal(
    modalDialog(
      uiOutput('modal_ui'),
      footer = NULL
    )
  )
  
  
  # See if log-in worked
  observeEvent(input$submit, {
    cp <- check_password(user = input$user,
                         password = input$password,
                         the_users = data$users)
    logged_in(cp)
    message('cp is ', cp)
    if(cp){
      lit <- 'Successful log-in'
    } else {
      lit <- 'That user/password combination does not exist'
    }
    log_in_text(lit)
  })
  
  # When OK button is pressed, attempt to log-in. If success,
  # remove modal.
  observeEvent(input$submit, {
    # Did login work?
    li <- logged_in()
    lit <- log_in_text()
    if(li){
      # Update the reactive modal_text
      modal_text(paste0('Logged in as ', input$user))
      removeModal()
    } else {
      # Update the reactive modal_text
      modal_text(lit)
    }
  })
  
  # Make a switcher between the log in vs. create account menus
  create_account <- reactiveVal(FALSE)
  observeEvent(input$create_account,{
    currently <- create_account()
    nowly <- !currently
    create_account(nowly)
  })
  observeEvent(input$submit_create_account,{
    currently <- create_account()
    nowly <- !currently
    create_account(nowly)
  })
  observeEvent(input$back,{
    currently <- create_account()
    nowly <- !currently
    create_account(nowly)
  })
  
  output$modal_ui <- renderUI({
    
    # Capture the log-in text
    lit <- mt <- log_in_text()
    # See if we're in account creation vs log in mode
    account_creation <- create_account()
    if(account_creation){
      fluidPage(
        fluidRow(
          column(12,
                 align = 'right',
                 actionButton('back',
                              'Back'))
        ),
        h3(textInput('create_user', 'Email'),
           textInput('create_password', 'Create password'),
           textInput('create_first_name', 'First name'),
           textInput('create_last_name', 'Last name'),
           textInput('create_position', 'Position'),
           textInput('create_institution', 'Institution')
        ),
        fluidRow(
          column(6, align = 'left', p(lit)),
          column(6, align = 'right',
                 actionButton('submit_create_account',
                              'Create account'))
        )
      )
    } else {
      fluidPage(
        h3(textInput('user', 'Username',
                     value = 'joe@databrew.cc'),
           passwordInput('password', 'Password', value = 'password')),
        fluidRow(
          column(6,
                 actionButton('submit',
                              'Submit')),
          column(6, align = 'right',
                 actionButton('create_account',
                              'Create account'))
        ),
        p(mt)
      )}
  })
  
  # Observe account creation
  observeEvent(input$submit_create_account,{
    x <- add_user(user = input$create_user,
             password = input$create_password,
             first_name = input$create_first_name,
             last_name = input$create_last_name,
             position = input$create_position,
             institution = input$create_institution,
             users = data$users)
    message('x is ', x)
    log_in_text(x)
    data$users <- dbGetQuery(conn = co,statement = 'SELECT * FROM users',
                             connection_object = co)
  })
  
  output$edit_table <- DT::renderDataTable({
    li <- logged_in()
    addy <- is_admin()
    if(addy){
      eddy <- list(target = 'cell', disable = list(columns = c(5)))
    } else {
      eddy <- FALSE
    }
    if(li){
      df <- data$users
      df <- df %>% dplyr::select(first_name, last_name,
                                 position, institution, email,
                                 tags)
      names(df) <- c('First', 'Last', 'Position', 'Institution',
                     'Emails', 'Tags')
      df <- df %>% arrange(First)
      DT::datatable(df, editable = eddy)#,
                    # colnames = c('First' = 'first_name',
                    #              'Last' = 'last_name',
                    #              'Position' = 'position', 
                    #              'Institution' = 'institution',
                    #              'Email' = 'email',
                    #              'Tags' = 'tags'))
    } else {
      NULL
    }
  })
  
  output$ui_send_email <- renderUI({
    et <- email_text()
    n <- length(email_people())
    n_text <- ifelse(n == 1, '1 person',
                     paste0(n, ' people', collapse = ''))
    out <- NULL
    if(!is.na(et)){
      if(et != ''){
        out <- fluidPage(
          HTML(
            "<a href=\"mailto:", et, "?subject=Bohemia\" target=\"_blank\">Click HERE to send email to the selected ", n_text, ".</a>")
        )
      }
    }
    return(out)
  })
  
  # Capture edits to data and store them
  proxy = dataTableProxy('edit_table')
  observeEvent(input$edit_table_cell_edit, {
    x <- data$users
    x <- x %>% arrange(first_name)
    info = input$edit_table_cell_edit
    i = info$row
    j = info$col
    v = info$value
    old_vals <- x[i,]
    id <- x$id[i]
    x[i, j] <- DT::coerceValue(v, x[i, j])
    replaceData(proxy, x, resetPaging = FALSE, rownames = FALSE)
    # Overwrite the database too
    old_email <- old_vals$email
    message('Deleting old row')
    dbSendQuery(conn = co,
                paste0("delete from users where email = '",
                       old_email, "'"))
    message('Replacing with updated row')
    dbWriteTable(conn = co, 
                 name = 'users', 
                 value = x[i,], 
                 row.names = FALSE,
                 overwrite = FALSE,
                 append = TRUE)
    # Update the in-memory object
    data$users <- x
  })
  
  output$ui_create_account <- renderUI({
    
    addy <- is_admin()
    li <- logged_in()
    selected_rows <- input$edit_table_rows_selected
    any_selected <- length(selected_rows) > 0
    if(li & addy){
      if(any_selected){
        fluidPage(
          column(6,
                 actionButton('new_entry',
                              'Add new entry',icon = icon('face'))),
          column(6,
                 actionButton('delete_entry',
                              'Delete selected entries',icon = icon('face')))
        )
      } else {
        fluidPage(
          column(6,
                 actionButton('new_entry',
                              'Add new entry',icon = icon('face'))),
          column(6)
        )
      }
      
    }
  })
  observeEvent(input$new_entry,{
    create_account(TRUE)
    log_in_text('')
    showModal(
      modalDialog(
        uiOutput('new_entry_ui'),
        easyClose = TRUE
      )
    )
  })
  
  output$new_entry_ui <- renderUI({
    lit <- log_in_text()
      fluidPage(
        h3(textInput('create_user', 'Email'),
           textInput('create_password', 'Create password'),
           textInput('create_first_name', 'First name'),
           textInput('create_last_name', 'Last name'),
           textInput('create_position', 'Position'),
           textInput('create_institution', 'Institution')
        ),
        fluidRow(
          column(6, align = 'left', p(lit)),
          column(6, align = 'right',
                 actionButton('submit_create_account',
                              'Create account'))
        )
      )
  })
  
  # Capture the selected rows
  observeEvent(input$edit_table_rows_selected,{
    selected_rows <- input$edit_table_rows_selected
    message('selected rows are')
    print(selected_rows)
    # emails
    df <- data$users
    df <- df[selected_rows,]
    emails <- sort(unique(df$email[!is.na(df$email)]))
    message('selected emails are')
    print(emails)
    email_people(emails)
    email_text(paste0(emails, collapse = ', '))
  })
  
  output$edit_text <- renderUI({
    addy <- is_admin()
    if(addy){
      column(6,
             p('Hold ctrl + click to select people. Double click a cell to edit it.'),
             p('Type any name, institution, "tag", etc. to filter people.'))
    } else {
      column(6,
             p('Hold ctrl + click to select people.'),
             p('Type any name, institution, "tag", etc. to filter people.'))
    }
  })
  
  observeEvent(input$delete_entry, {
    selected_rows <- input$edit_table_rows_selected
    df <- data$users
    df <- df[selected_rows,]
    emails <- sort(unique(df$email[!is.na(df$email)]))
    showModal(modalDialog(
      title = 'Confirm deletion',
      fluidPage(
        paste0('Are you sure you want to delete the entries for ',
               paste0(emails, collapse = ', '), '?'),
        actionButton('sure', 'Yes', icon = icon('check'))
      )
    ))
  })
  observeEvent(input$sure,{
    selected_rows <- input$edit_table_rows_selected
    df <- data$users
    df <- df[selected_rows,]
    emails <- sort(unique(df$email[!is.na(df$email)]))
    for(i in 1:length(emails)){
      this_email <- emails[i]
      message('Deleting entry for ', this_email)
      dbSendQuery(conn = co,
                  paste0("delete from users where email = '",
                         this_email, "'"))
    }
    
    # Update the in-memory data
    df <- data$users <- get_users()
    removeModal()
  })
}
onStop(function() {
  message('Disconnecting from database')
  dbDisconnect(co)
})
shinyApp(ui, server)