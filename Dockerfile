# See: https://github.com/phusion/passenger-docker
# Latest image versions:
# https://github.com/phusion/passenger-docker/blob/master/CHANGELOG.md
FROM phusion/passenger-ruby27:2.0.0

ENV HOME /root

# Use baseimage-docker's init process.
CMD ["/sbin/my_init"]

# Yarn package
RUN echo "Start here"
RUN curl -sS https://raw.githubusercontent.com/yarnpkg/releases/gh-pages/debian/pubkey.gpg | apt-key add -
RUN echo "deb https://dl.yarnpkg.com/debian/ stable main" | tee /etc/apt/sources.list.d/yarn.list

# Postgres
RUN curl -sS https://www.postgresql.org/media/keys/ACCC4CF8.asc | apt-key add -

RUN apt-get update -qq
RUN apt-get install --yes --fix-missing pkg-config apt-utils build-essential \
              cmake automake tzdata locales curl git gnupg ca-certificates \
              libpq-dev wget libxrender1 libxext6 libsodium23 libsodium-dev \
              netcat postgresql-client shared-mime-info udev gnupg \
              python2-minimal

# NodeJS
RUN curl -fsSL https://deb.nodesource.com/setup_lts.x | bash -
RUN apt install --yes --fix-missing nodejs yarn

# Use Ruby 2.7.4
RUN bash -lc 'rvm --default use ruby-2.7.4'

# Cleanup
RUN apt-get clean && apt-get autoremove --yes \
  && rm -rf /var/lib/apt/lists/* /tmp/* /var/tmp/*

# Use en_CA.utf8 as our locale
RUN locale-gen en_CA.utf8
ENV LANG en_CA.utf8
ENV LANGUAGE en_CA:en
ENV LC_ALL en_CA.utf8

# Container uses 999 for docker user
RUN /usr/sbin/usermod -u 999 app

ENV APP_HOME /home/app/workshops
WORKDIR $APP_HOME
RUN rm docker-compose.yml
RUN chown app -R ./
RUN echo "disable-ipv6" >> ~/.gnupg/dirmngr.conf

EXPOSE 80 443
ADD entrypoint.sh /sbin/
RUN chmod 755 /sbin/entrypoint.sh
RUN rm entrypoint.sh
RUN mkdir -p /etc/my_init.d
RUN ln -s /sbin/entrypoint.sh /etc/my_init.d/entrypoint.sh
RUN echo 'export PATH=./bin:$PATH:/usr/local/rvm/rubies/ruby-2.7.4/bin' >> /root/.bashrc
RUN echo 'alias rspec="bundle exec rspec"' >> /root/.bashrc
RUN echo 'alias restart="passenger-config restart-app /home/app/workshops"' >> /root/.bashrc
ENTRYPOINT ["/sbin/entrypoint.sh"]
