# See: https://github.com/phusion/passenger-docker
# Latest image versions: https://github.com/phusion/passenger-docker/blob/master/CHANGELOG.md
FROM phusion/passenger-ruby27:2.4.1

ENV HOME /root

# Use baseimage-docker's init process.
CMD ["/sbin/my_init"]

# prevent gpg from using IPv6 to connect to keyservers
RUN mkdir -p ~/.gnupg
RUN echo "disable-ipv6" >> ~/.gnupg/dirmngr.conf

# Yarn package
RUN curl -sS https://raw.githubusercontent.com/yarnpkg/releases/gh-pages/debian/pubkey.gpg | apt-key add -
RUN echo "deb https://dl.yarnpkg.com/debian/ stable main" | tee /etc/apt/sources.list.d/yarn.list

# Postgres
RUN curl -sS https://www.postgresql.org/media/keys/ACCC4CF8.asc | apt-key add -

RUN apt-get update -qq && apt-get dist-upgrade --yes && \
    apt-get install --yes pkg-config apt-utils build-essential cmake automake && \
    apt-get upgrade --fix-missing --yes --allow-remove-essential \
    -o Dpkg::Options::="--force-confold"

# Update Node
RUN curl -sL https://deb.nodesource.com/setup_16.x | bash - && \
    apt-get install --yes nodejs

RUN apt-get install --yes tzdata udev locales curl git gnupg ca-certificates \
    libpq-dev wget libxrender1 libxext6 libsodium23 libsodium-dev yarn \
    gcc make zlib1g-dev sqlite3 libgmp-dev libc6-dev gcc-multilib g++-multilib \
    shared-mime-info && \
    apt-get clean && apt-get autoremove --yes && \
    rm -rf /var/lib/apt/lists/* /tmp/* /var/tmp/*

# Use en_CA.utf8 as our locale
RUN locale-gen en_CA.utf8
ENV LANG en_CA.utf8
ENV LANGUAGE en_CA:en
ENV LC_ALL en_CA.utf8

#ADD rails-env.conf /etc/nginx/main.d/rails-env.conf
#RUN chmod 644 /etc/nginx/main.d/rails-env.conf

ENV APP_HOME /home/app/workshops
COPY --chown=app:app ./app ${APP_HOME}/app
COPY --chown=app:app ./bin ${APP_HOME}/bin
COPY --chown=app:app ./config ${APP_HOME}/config
COPY --chown=app:app ./db ${APP_HOME}/db
COPY --chown=app:app ./lib ${APP_HOME}/lib
COPY --chown=app:app ./log ${APP_HOME}/log
COPY --chown=app:app ./public ${APP_HOME}/public
COPY --chown=app:app ./storage ${APP_HOME}/storage
COPY --chown=app:app ./vendor ${APP_HOME}/vendor
COPY --chown=app:app \
 Gemfile \
 Gemfile.lock \
 package.json \
 yarn.lock \
 Passengerfile.json \
 nginx.conf.erb \
 Rakefile \
 config.ru \
 .rspec \
 ${APP_HOME}/

WORKDIR $APP_HOME

RUN touch $APP_HOME/config/app.yml
RUN echo "disable-ipv6" >> ~/.gnupg/dirmngr.conf
RUN chown app -R ./

EXPOSE 3000
ADD entrypoint.sh /sbin/
RUN chmod 755 /sbin/entrypoint.sh
RUN mkdir -p /etc/my_init.d
RUN ln -s /sbin/entrypoint.sh /etc/my_init.d/entrypoint.sh
RUN echo 'export PATH=$PATH:./bin:/usr/local/rvm/rubies/ruby-2.7.7/bin'>> /root/.bashrc
RUN echo 'alias rspec="bundle exec rspec"' >> /root/.bashrc
ENTRYPOINT ["/sbin/entrypoint.sh"]
