FROM phusion/passenger-ruby23:latest

RUN apt-get update \
    && apt-get upgrade -y -o Dpkg::Options::="--force-confold" \
    && apt-get install -y nodejs tzdata \
    && rm -rf /var/lib/apt/lists/*

# Install ruby 2.3.4 in order to match what we are developing against.
RUN bash -lc 'rvm install ruby-2.3.4'
RUN bash -lc 'rvm --default use ruby-2.3.4'
RUN gem install bundler

ENV RAILS_ENV production
ENV RAILS_SERVE_STATIC_FILES 1

RUN mkdir /home/app/cypress

WORKDIR /home/app/cypress

ADD Gemfile /home/app/cypress/Gemfile
ADD Gemfile.lock /home/app/cypress/Gemfile.lock

RUN chown -R app:app .

RUN su app -c 'bundle install --without development test'

ADD . /home/app/cypress

# If the tmp directory doesn't exist then the app will not be able to run.
# By creating it here it will get chowned correctly by the next declaration.
RUN mkdir -p tmp public/data

# This line is a duplicate however it is done to significantly speed up testing. With this line twice
# we are able to do the bundle install earlier on which means it is cached more often.
RUN chown -R app:app .

RUN mkdir /etc/service/unicorn
ADD docker_unicorn_start.sh /etc/service/unicorn/run
RUN chmod 755 /etc/service/unicorn/run

RUN mkdir /etc/service/cypress_delayed_job_1
ADD docker_delayed_job.sh /etc/service/cypress_delayed_job_1/run
RUN chmod 755 /etc/service/cypress_delayed_job_1/run

# Setup other workers based on first worker. This makes it where tweaking the number of workers
# just requires changing this WORKER_COUNT. Unfortunately does not allow tweaking after build is completed.
ARG WORKER_COUNT=4
RUN if [ $WORKER_COUNT -gt 1 ]; then \
      for i in $(seq 2 1 $WORKER_COUNT); do \
        cp -R /etc/service/cypress_delayed_job_1 /etc/service/cypress_delayed_job_$i; \
      done; \
    fi

EXPOSE 3000
