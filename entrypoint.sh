#!/bin/bash
set -e

echo
echo "Welcome to OS:"
uname -v
cat /etc/issue

echo
echo "Setting system timezone..."
export DEBIAN_FRONTEND=noninteractive DEBCONF_NONINTERACTIVE_SEEN=true
echo "tzdata tzdata/Areas select America" > /tmp/tz.txt
echo "tzdata tzdata/Zones/America select Edmonton" >> /tmp/tz.txt
debconf-set-selections /tmp/tz.txt
rm /etc/timezone
rm /etc/localtime
dpkg-reconfigure --frontend noninteractive tzdata

if [ ! -e /usr/local/rvm/gems/ruby-2.7.4 ]; then
  echo
  echo "Create gemset..."
  gpg --keyserver keys.openpgp.org --recv-keys 409B6B1796C275462A1703113804BB82D39DC0E3 7D2BAF1CF37B13E2069D6956105BD0E739499BDB
  /usr/bin/curl -sSL https://get.rvm.io | bash -s stable
  bash -lc 'rvm --default use ruby-2.7.4'
  /usr/local/rvm/bin/rvm gemset create ruby-2.7.4
  /usr/local/rvm/bin/rvm gemset use ruby-2.7.4@global
  /usr/local/rvm/bin/rvm cleanup all
  /usr/local/rvm/bin/rvm reload
fi

echo
echo "Ruby version:"
ruby -v

echo
echo "Node version:"
node --version

echo
echo "Yarn version:"
yarn --version

echo
echo "Installing latest bundler..."
/usr/local/rvm/bin/rvm-exec 2.7.4 gem install bundler

if [ ! -e /usr/local/rvm/gems/ruby-2.7.4/gems/rails-5.2.4.6 ]; then
  echo
  echo "Installing Rails 5.2.4.6..."
  su - app -c "cd /home/app/workshops; /usr/local/rvm/bin/rvm-exec 2.7.4 gem install rails -v 5.2.4.6"
fi

if [ ! -e /home/app/workshops/bin ]; then
  echo
  echo "Starting new rails app..."
  su - app -c "cd /home/app; rails new workshops"

  echo
  echo "Bundle install..."
  RAILS_ENV=development /usr/local/rvm/bin/rvm-exec 2.7.4 bundle install

  echo
  echo "Adding default Settings..."
  rake ws:init_settings

  echo
  echo "Creating admins..."
  if [ -e lib/tasks/birs.rake ]; then
    rake birs:create_admin RAILS_ENV=development
  else
    rake ws:create_admins RAILS_ENV=development
  fi
fi


echo
echo "Bundle update..."
RAILS_ENV=development /usr/local/rvm/bin/rvm-exec 2.7.4 bundle update


root_owned_files=`find /usr/local/rvm/gems -user root -print`
if [ -z "$root_owned_files" ]; then
  echo
  echo "Changing gems to non-root file permissions..."
  chown app:app -R /usr/local/rvm/gems
fi

if [ -e /home/app/workshops/db/migrate ]; then
  echo
  echo "Running migrations..."
  cd /home/app/workshops
  SECRET_KEY_BASE=token DB_USER=$DB_USER DB_PASS=$DB_PASS
  rake db:migrate RAILS_ENV=production
  rake db:migrate RAILS_ENV=development
  rake db:migrate RAILS_ENV=test
fi

echo
echo "Checking for WebPacker..."
if [ ! -e /home/app/workshops/bin/webpack ]; then
  echo "Installing webpacker..."
  RAILS_ENV=development bundle exec rails webpacker:install
  echo "Done!"
  echo
fi

if [ "$RAILS_ENV" == "production" ]; then
  echo
  echo "Changing to non-root file permissions..."
  chown app:app -R /usr/local/rvm/gems
  if [ ! -e /home/app/workshops/tmp ]; then
   mkdir /home/app/workshops/tmp
   mkdir -p /home/app/workshops/vendor/cache
  fi
  chown app:app -R /home/app/workshops

  echo
  echo "Compiling Assets..."
  chmod 755 /home/app/workshops/node_modules
  su - app -c "cd /home/app/workshops; yarn install --latest"
  #su - app -c "cd /home/app/workshops; yarn upgrade"
  su - app -c "cd /home/app/workshops; RAILS_ENV=development SECRET_KEY_BASE=token bundle exec rake assets:precompile --trace"
  su - app -c "cd /home/app/workshops; yarn"
fi

if [ "$APPLICATION_HOST" == "localhost" ]; then
  echo
  echo "Launching webpack-dev-server..."
  su - app -c "ruby /home/app/workshops/bin/webpack-dev-server &"
fi

echo
echo "Starting web server..."
bundle exec passenger start #--min-instances 2
