# Setting up shiny server on EC2 for www.bohemia.team

(Based loosely on the instructions at: https://www.digitalocean.com/community/tutorials/how-to-set-up-shiny-server-on-ubuntu-16-04)

- Deploy an instance to ec2

## EC2 instance

- Spin up a Ubuntu Server 18.04 LTS (HVM), SSD server
- Instance type: medium
- Configuration
  - Defaults except:
  - Network: use the aggregate-vpc group (see ODK set up guide for details)
  - Auto-assign Public IP: Enable
  - IAM role: aggregate role
- Storage: 30gb
- Tags: none
- Security group: vpc-aggregate group
- Associate the purchased bohemia.team domain with the IP (elastic IP)

## Set up an alias

Add the following to the end of `~/.bashrc`
```
alias shiny='ssh -i "/home/joebrew/.ssh/openhdskey.pem" ubuntu@bohemia.team'
```


## Installing R and associated dependencies

```
sudo apt-get update && sudo apt-get upgrade
sudo apt-key adv --keyserver keyserver.ubuntu.com --recv-keys E298A3A825C0D65DFD57CBB651716619E084DAB9
sudo add-apt-repository 'deb https://cloud.r-project.org/bin/linux/ubuntu bionic-cran35/'
sudo apt update
sudo apt install r-base


sudo apt-get install -y libcurl4-openssl-dev
sudo apt-get install -y libxml2-dev
sudo apt install default-jdk
export LD_LIBRARY_PATH=/usr/lib/jvm/java-11-openjdk-amd64/lib/server
sudo R CMD javareconf
```

## Configure R

Change R package directory from user-based to system-wide:
```
sudo nano /usr/lib/R/etc/Renviron
```
Your Renviron file should look like this when you’re done.
```
#R_LIBS_USER=${R_LIBS_USER-‘~/R/x86_64-pc-linux-gnu-library/3.0’}
R_LIBS_USER=${R_LIBS_USER-‘~/Library/R/3.0/library’}
```

Check lib paths in R to make sure your package library changed correctly.
R
`.libPaths()`

`/usr/local/lib/R/site-library` should be the first of the library paths.


Make your new package lib readable for Shiny Server.
```
sudo chmod 777 /usr/lib/R/site-library
```


### Install shiny

```
sudo su - -c "R -e \"install.packages('shiny', repos='http://cran.rstudio.com/')\""
```

### Install shiny server

```
wget https://download3.rstudio.org/ubuntu-12.04/x86_64/shiny-server-1.5.5.872-amd64.deb
md5sum shiny-server-1.5.5.872-amd64.deb
sudo apt-get update
sudo apt-get install gdebi-core
sudo gdebi shiny-server-1.5.5.872-amd64.deb
# Check that it's running on port 3838
sudo netstat -plunt | grep -i shiny
sudo ufw allow 3838
```

### Setting up https

```
sudo apt install nginx
sudo apt-get update
sudo apt-get install software-properties-common
sudo add-apt-repository universe
sudo add-apt-repository ppa:certbot/certbot
sudo apt-get update
sudo apt-get install certbot python-certbot-nginx
sudo certbot run --nginx --non-interactive --agree-tos -m joebrew@gmail.com --redirect -d bohemia.team
```

### Set up proxy, certificate, etc.

```
sudo nano /etc/nginx/nginx.conf
```

Copy the following into the http block of /etc/nginx/nginx.conf

```
http {
    ...
    # Map proxy settings for RStudio
    map $http_upgrade $connection_upgrade {
        default upgrade;
        '' close;
    }
}
```

Now create a new block

```
sudo nano /etc/nginx/sites-available/bohemia.team
```

In /etc/nginx/sites-available/bohemia.team, add the following:

```
server {
   listen 80 default_server;
   listen [::]:80 default_server ipv6only=on;
   server_name bohemia.team www.bohemia.team;
   return 301 https://$server_name$request_uri;
}
server {
   listen 443 ssl;
   server_name bohemia.team www.bohemia.team;
   ssl_certificate /etc/letsencrypt/live/bohemia.team/fullchain.pem;
   ssl_certificate_key /etc/letsencrypt/live/bohemia.team/privkey.pem;
   ssl_protocols TLSv1 TLSv1.1 TLSv1.2;
   ssl_prefer_server_ciphers on;
   ssl_ciphers AES256+EECDH:AES256+EDH:!aNULL;

   location / {
       proxy_pass http://18.218.87.64:3838/;
       proxy_redirect http://18.218.87.64:3838/ https://$host/;
       proxy_http_version 1.1;
       proxy_set_header Upgrade $http_upgrade;
       proxy_set_header Connection $connection_upgrade;
       proxy_read_timeout 20d;
   }
}
```

# Enable the new block by creating a symlink

```
sudo ln -s /etc/nginx/sites-available/bohemia.team /etc/nginx/sites-enabled/bohemia.team
```

Disable the default block since our server now handles all incoming traffic
```
sudo rm -f /etc/nginx/sites-enabled/default
```

Test the config:
```
sudo nginx -t
```
Restart nginx
```
sudo systemctl restart nginx
```

## install postgres

```
sudo apt update
sudo apt install postgresql postgresql-contrib
sudo -i -u postgres
createuser --interactive
- name of role: ubuntu
- superuser: y
createdb ubuntu
createuser --interactive
- name of role: shiny
- superuser: y
createdb shiny
```


## hosting interactive R docs

Install the following:
```
sudo su - -c "R -e \"install.packages('rmarkdown', repos='http://cran.rstudio.com/')\""
```

Check that it worked at
https://bohemia.team/sample-apps/rmd/



- Intall some additional software:
```
sudo apt-get -y install \
    apache2-utils \
    pandoc \
    pandoc-citeproc \
    libssl-dev \
    libcurl4-gnutls-dev \
    libcairo2-dev \
    libgdal-dev \
    libgeos-dev \
    libproj-dev \
    libxml2-dev \
    libxt-dev \
    libv8-dev
sudo apt-get update
```



- Install some R packages
- It's useful to use the `databrew::list_packages`

```
sudo add-apt-repository ppa:marutter/c2d4u3.5
sudo apt update
sudo apt install r-cran-dplyr
sudo su - -c "R -e \"install.packages('devtools')\"";
sudo su - -c "R -e \"install.packages('broom')\"";
sudo su - -c "R -e \"install.packages('broomExtra')\"";
sudo su - -c "R -e \"install.packages('dbplyr')\""
sudo su - -c "R -e \"install.packages('DBI')\"";
sudo su - -c "R -e \"install.packages('deldir')\"";
sudo su - -c "R -e \"install.packages('DescTools')\"";
sudo su - -c "R -e \"install.packages('dismo')\"";
sudo su - -c "R -e \"install.packages('dplyr')\"";
sudo su - -c "R -e \"install.packages('DT')\"";
sudo su - -c "R -e \"install.packages('DTedit')\"";
sudo su - -c "R -e \"install.packages('extrafont')\""
sudo su - -c "R -e \"install.packages('geosphere')\"";
sudo su - -c "R -e \"install.packages('gsheet')\""
sudo su - -c "R -e \"install.packages('ggplot2')\"";
sudo su - -c "R -e \"install.packages('ggmap')\""
sudo su - -c "R -e \"install.packages('ggthemes')\""
sudo su - -c "R -e \"install.packages('ggpubr')\"";
sudo su - -c "R -e \"install.packages('graphics')\"";
sudo su - -c "R -e \"install.packages('haven')\""
sudo su - -c "R -e \"install.packages('highcharter')\"";
sudo su - -c "R -e \"install.packages('Hmisc')\"";
sudo su - -c "R -e \"install.packages('htmltools')\"";
sudo su - -c "R -e \"install.packages('htmlwidgets')\"";
sudo su - -c "R -e \"install.packages('jqr')\"";
sudo su - -c "R -e \"install.packages('jsonlite')\"";
sudo su - -c "R -e \"install.packages('leaflet')\"";
sudo su - -c "R -e \"install.packages('leaflet.extras')\"";
sudo su - -c "R -e \"install.packages('lubridate')\""
sudo su - -c "R -e \"install.packages('maps')\""
sudo su - -c "R -e \"install.packages('maptools')\"";
sudo su - -c "R -e \"install.packages('MASS')\"";
sudo su - -c "R -e \"install.packages('methods')\"";
sudo su - -c "R -e \"install.packages('modelr')\""
sudo su - -c "R -e \"devtools::install_github('databrew/nd3')\"";
sudo su - -c "R -e \"install.packages('nlme')\"";
sudo su - -c "R -e \"install.packages('openxlsx')\"";
sudo su - -c "R -e \"install.packages('plotly')\"";
sudo su - -c "R -e \"install.packages('plyr')\"";
sudo su - -c "R -e \"install.packages('prettymapr')\"";
sudo su - -c "R -e \"install.packages('raster')\"";
sudo su - -c "R -e \"install.packages('rCharts')\"";
sudo su - -c "R -e \"install.packages('RCurl')\""
sudo su - -c "R -e \"install.packages('readr')\"";
sudo su - -c "R -e \"install.packages('readxl')\"";
sudo su - -c "R -e \"install.packages('rgeos')\"";
sudo su - -c "R -e \"install.packages('rmarkdown')\"";
sudo su - -c "R -e \"install.packages('RPostgres')\"";
sudo su - -c "R -e \"install.packages('RPostgreSQL')\""
sudo su - -c "R -e \"install.packages('rvest')\"";
sudo su - -c "R -e \"install.packages('scales')\""
sudo su - -c "R -e \"install.packages('sf')\"";
sudo su - -c "R -e \"install.packages('shiny')\"";
sudo su - -c "R -e \"install.packages('shinydashboard')\"";
sudo su - -c "R -e \"install.packages('shinyjqui')\"";
sudo su - -c "R -e \"install.packages('shinyjs')\"";
sudo su - -c "R -e \"install.packages('sp')\"";
sudo su - -c "R -e \"install.packages('spacetime')\"";
sudo su - -c "R -e \"install.packages('spacyr')\"";
sudo su - -c "R -e \"install.packages('survey')\"";
sudo su - -c "R -e \"install.packages('textclean')\"";
sudo su - -c "R -e \"install.packages('tibble')\"";
sudo su - -c "R -e \"install.packages('tidylog')\"";
sudo su - -c "R -e \"install.packages('tidyr')\"";
sudo su - -c "R -e \"install.packages('tidyverse')\""
sudo su - -c "R -e \"install.packages('units')\"";
sudo su - -c "R -e \"install.packages('V8')\"";
sudo su - -c "R -e \"install.packages('VGAM')\"";
sudo su - -c "R -e \"install.packages('xlsx')\"";
sudo su - -c "R -e \"install.packages('xtable')\"";
sudo su - -c "R -e \"install.packages('yaml')\"";
sudo su - -c "R -e \"devtools::install_github('rstudio/DT')\""
sudo su - -c "R -e \"install.packages('gpclib')\"";
sudo su - -c "R -e \"install.packages('qrcode')\"";
sudo su - -c "R -e \"install.packages('rgdal')\"";
sudo su - -c "R -e \"install.packages('kableExtra')\"";
sudo su - -c "R -e \"install.packages('googlesheets')\"";
sudo su - -c "R -e \"devtools::install_github('databrew/bohemia', subdir = 'rpackage/bohemia', dependencies = TRUE, force = TRUE)\""

```

Test:
```
sudo git clone https://github.com/joebrew/minimal
sudo systemctl restart shiny-server
```

Now go to https://bohemia.team/minimal

Set up permissions
```
sudo groupadd shiny-apps
sudo usermod -aG shiny-apps ubuntu
sudo usermod -aG shiny-apps shiny
cd /srv/shiny-server
sudo chown -R ubuntu:shiny-apps .
sudo chmod g+w .
sudo chmod g+s .
```

Get the bohemia repo locally
```
cd /home/ubuntu
git clone https://github.com/databrew/bohemia
cd bohemia/rpackage/bohemia
Rscript build_package
cd /home/ubuntu/bohemia/shiny/directory
mkdir credentials
```

Move things to the serving area

```
cp -r bohemia/shiny/operations /srv/shiny-server
cp -r bohemia/shiny/directory /srv/shiny-server
cp -r bohemia/shiny/datamanager /srv/shiny-server

sudo systemctl restart shiny-server

```


- Port from local to remote
```
mkdir ~/Documents
scp -r -i "/home/joebrew/.ssh/openhdskey.pem" ~/Documents/vilaweb/analyses/deleted_tweets ubuntu@bohemia.team:/home/ubuntu/Documents
```

- On remote machine, move to deploy area

```
sudo cp -r ~/Documents/deleted_tweets /srv/shiny-server/piulets
```
