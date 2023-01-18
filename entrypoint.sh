#!/bin/bash
set -e

source /etc/profile.d/rvm.sh

echo
echo "Welcome to OS:"
uname -v
cat /etc/issue
sed -i -e 's/mesg n .*true/tty -s \&\& mesg n/g' ~/.profile


echo
echo "Setting system timezone..."
export DEBIAN_FRONTEND=noninteractive DEBCONF_NONINTERACTIVE_SEEN=true
echo "tzdata tzdata/Areas select America" > /tmp/tz.txt
echo "tzdata tzdata/Zones/America select Edmonton" >> /tmp/tz.txt
debconf-set-selections /tmp/tz.txt
rm /etc/timezone
rm /etc/localtime
dpkg-reconfigure --frontend noninteractive tzdata

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
/usr/local/rvm/bin/rvm-exec 2.7.7 gem install bundler

echo
echo "Bundle install..."
RAILS_ENV=development /usr/local/rvm/bin/rvm-exec 2.7.7 bundle install

if [ ! -d "${GEM_HOME}/gems" ]; then
  echo
  echo "Gems not found in $GEM_HOME!"
  echo
  exit
fi

echo
echo "Changing to non-root file permissions..."
chown app:app -R /usr/local/rvm/gems

echo
echo "Running migrations..."
RAILS_ENV=development /usr/local/rvm/bin/rvm-exec 2.7.7 bundle exec rails db:migrate

echo
echo "Checking for WebPacker..."
if [ ! -e /home/app/workshops/bin/webpack ]; then
  echo "Installing webpacker..."
  RAILS_ENV=development /usr/local/rvm/bin/rvm-exec 2.7.7 bundle exec rails webpacker:install
  echo "Done!"
  echo
fi

if [ ! -e /home/app/workshops/tmp ]; then
  mkdir /home/app/workshops/tmp
  mkdir -p /home/app/workshops/vendor/cache
fi
chown app:app -R /home/app/workshops

echo
echo "Compiling Assets..."
su - app -c "cd /home/app/workshops; yarn install"
su - app -c "cd /home/app/workshops; RAILS_ENV=development SECRET_KEY_BASE=token bundle exec rake assets:precompile --trace"
su - app -c "cd /home/app/workshops; yarn"

echo
echo "Launching webpack-dev-server..."
su - app -c "ruby /home/app/workshops/bin/webpack-dev-server &"
echo
echo "Starting web server..."
/usr/local/rvm/bin/rvm-exec 2.7.7 bundle exec passenger start --min-instances 2
