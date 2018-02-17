

# functions
unalias cli 2>/dev/null
cli() {
 docker run -it --rm -w /app -v $(pwd):/app --net=host oveits/angular-cli:1.4.3 $@
}
unalias npm 2>/dev/null
npm() {
 if [[ "$@" == "i" ]] || [[ "$@" == "install" ]] ; then
    sudo chown -R $(whoami) .
 fi
}


# aliases
alias ng='cli ng @'
alias protractor='docker run -it --privileged --rm --net=host -v /dev/shm:/dev/shm -v $(pwd):/protractor webnicer/protractor-headless $@'
alias webapp='docker run --rm --name angular-cli-hello-world-with-docker-example -d -p 80:80 oveits/angular-cli-hello-world-with-docker $@'
alias consuming='docker run --rm --name consuming-a-restful-web-service-with-angular -d -p 80:80 oveits/consuming-a-restful-web-service-with-angular $@'
alias own='sudo chown -R $(whoami) .'

