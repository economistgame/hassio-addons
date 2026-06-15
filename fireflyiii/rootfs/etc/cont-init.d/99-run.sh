#!/usr/bin/env bashio
# shellcheck shell=bash
set -e
# hadolint ignore=SC2155

########
# Init #
########

# APP_KEY
APP_KEY="qaqkIt-qyxmi5-dybhen12345678910122"

# If not base64
if [[ ! "$APP_KEY" == *"base64"* ]]; then
    # Check APP_KEY format
    if [ ! "${#APP_KEY}" = 32 ]; then bashio::exit.nok "Your APP_KEY has ${#APP_KEY} instead of 32 characters"; fi
fi

# Backup APP_KEY file
bashio::log.info "Backuping APP_KEY to /config/addons_config/fireflyiii/APP_KEY_BACKUP.txt"
bashio::log.warning "Changing this value will require to reset your database"

# Get current app_key
mkdir -p /config/addons_config/fireflyiii
touch /config/addons_config/fireflyiii/APP_KEY_BACKUP.txt
CURRENT=$(sed -e '/^[<blank><tab>]*$/d' /config/addons_config/fireflyiii/APP_KEY_BACKUP.txt | sed -n -e '$p')

# Save if new
if [ "$CURRENT" != "$APP_KEY" ]; then
    echo "$APP_KEY" >> /config/addons_config/fireflyiii/APP_KEY_BACKUP.txt
fi

# Update permissions
mkdir -p /config/addons_config/fireflyiii
chown -R www-data:www-data /config/addons_config/fireflyiii
chown -R www-data:www-data /var/www/html/storage
chmod -R 775 /config/addons_config/fireflyiii

###################
# Define database #
###################

bashio::log.info "Defining database"
case $(bashio::config 'DB_CONNECTION') in

    # Use sqlite
    sqlite_internal)
        bashio::log.info "Using built in sqlite"

        # Set variable
        export DB_CONNECTION=sqlite
        export DB_DATABASE=/config/addons_config/fireflyiii/database/database.sqlite

        # Creating folders
        mkdir -p /config/addons_config/fireflyiii/database
        chown -R www-data:www-data /config/addons_config/fireflyiii/database

        # Creating database
        if [ ! -f /config/addons_config/fireflyiii/database/database.sqlite ]; then
            # Create database
            touch /config/addons_config/fireflyiii/database/database.sqlite
            # Install database
            echo "updating database"
            php artisan migrate:refresh --seed --quiet
            php artisan firefly-iii:upgrade-database --quiet
            php artisan passport:install --quiet
        fi

        # Creating symlink
        rm -r /var/www/html/storage/database
        ln -s /config/addons_config/fireflyiii/database /var/www/html/storage

        # Updating permissions
        chmod 775 /config/addons_config/fireflyiii/database/database.sqlite
        chown -R www-data:www-data /config/addons_config/fireflyiii
        chown -R www-data:www-data /var/www/html/storage
        ;;
esac

########################
# Define upload folder #
########################

bashio::log.info "Defining upload folder"

# Creating folder
if [ ! -d /config/addons_config/fireflyiii/upload ]; then
    mkdir -p /config/addons_config/fireflyiii/upload
    chown -R www-data:www-data /config/addons_config/fireflyiii/upload
fi

# Creating symlink
if [ -d /var/www/html/storage/ha_upload ]; then
    rm -r /var/www/html/storage/ha_upload
fi
ln -s /config/addons_config/fireflyiii/upload /var/www/html/storage/ha_upload

# Updating permissions
chown -R www-data:www-data /config/addons_config/fireflyiii
chown -R www-data:www-data /var/www/html/storage
chmod -R 775 /config/addons_config/fireflyiii

# Test
f=/config/addons_config/fireflyiii
while [[ $f != / ]]; do
    chmod 755 "$f"
    f=$(dirname "$f")
done

################
# CRON OPTIONS #
################

if bashio::config.has_value 'Updates'; then
    # Align update with options
    echo ""
    FREQUENCY=$(bashio::config 'Updates')
    bashio::log.info "$FREQUENCY updates"
    echo ""

    # Sets cron // do not delete this message
    cp /templates/cronupdate /etc/cron."${FREQUENCY}"/
    chmod 755 /etc/cron."${FREQUENCY}"/cronupdate

    # Sets cron to run with www-data user
    # sed -i 's|root|www-data|g' /etc/crontab

    # Starts cron
    service cron start
fi

##############
# LAUNCH APP #
##############

bashio::log.info "Please wait while the app is loading !"

if bashio::config.true 'silent'; then
    bashio::log.warning "Silent mode activated. Only errors will be shown. Please disable in addon options if you need to debug"
    sudo -Eu www-data bash -c 'cd /var/www/html && /scripts/11-execute-things.sh >/dev/null'
else
    sudo -Eu www-data bash -c 'cd /var/www/html && /scripts/11-execute-things.sh'
fi
