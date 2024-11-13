#!/usr/bin/env ruby

require 'fileutils'

@project = ARGV[0]
@version = ARGV[1]

# Must use an rpm-based image (it can also build debs)
@image = 'ezbake-builder'
@container = "#{@project}-builder"
@timestamp = Time.now.strftime('%Y%m%d_%H%M%S')
@debs = "base-bionic-i386.cow base-bookworm-i386.cow base-bullseye-i386.cow base-buster-i386.cow base-focal-i386.cow base-jammy-i386.cow base-noble-i386.cow"
@rpms = "pl-el-7-x86_64 pl-el-8-x86_64 pl-el-9-x86_64 pl-sles-12-x86_64 pl-sles-15-x86_64"

def image_exists
    !`docker images -q #{@image}`.strip.empty?
end

def container_exists
    !`docker container ls --all --filter 'name=#{@container}' --format json`.strip.empty?
end

def teardown
    if container_exists
        puts "Stopping #{@container}"
        `docker stop #{@container}`
        `docker rm #{@container}`
    end
end

def run(cmd)
    puts "\033[32mRunning #{cmd}\033[0m"
    puts `docker exec #{@container} /bin/bash --login -c '#{cmd}'`
end

begin
    # If the Dockerfile has changed since this was last built,
    # delete all containers and do `docker rmi ezbake-builder`
    unless image_exists
        puts "Building ezbake-builder image"
        `docker build -t ezbake-builder .`
    end

    puts 'Setting up container'
    teardown if container_exists
    #`docker run -d --name #{@container} -v #{__dir__}/../ezbake:/ezbake -v #{__dir__}/../#{@project}:/#{@project} --platform=linux/amd64 #{@image} /bin/sh -c 'tail -f /dev/null'`
    `docker run -d --name #{@container} -v #{__dir__}/../#{@project}:/#{@project} --platform=linux/amd64 #{@image} /bin/sh -c 'tail -f /dev/null'`

    # We don't yet need to do this. When we have our own version of ezbake, we will
    # need to check it out and install it here (unless we have it uploaded in a different
    # namespace that can be pulled down automatically) and then modify the project.clj
    # file to use that ezbake instead.
    #puts "Installing ezbake"
    #run("cd /ezbake && lein install")

    puts "Building #{@project}"
    run("cd /#{@project} && git checkout #{@version} && rm -rf ruby && rm -rf output")
    run("cd /#{@project} && bundle install --without test")
    run("cd /#{@project} && lein install")
    run("cd /#{@project} && COW=\"#{@debs}\" MOCK=\"#{@rpms}\" GEM_SOURCE='https://rubygems.org' EZBAKE_ALLOW_UNREPRODUCIBLE_BUILDS=true EZBAKE_NODEPLOY=true LEIN_PROFILES=ezbake lein with-profile user,ezbake,provided,internal ezbake local-build")
    run("find /#{@project}/output -type d -name \"*i386*\" -exec rm -rf {} +")
ensure
    `git checkout plumbing`
    teardown
end