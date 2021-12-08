# devkns

Script for automated deployment on k3s of:

- Communication: NATS, Kafka or RabbitMQ
- Database: Elasticsearch or InfluxDB
- Processing: OpenFaas
- Dashboard: Kibana



## [Option 1] Installation

`curl`, `jq` and `nc` are required for the script to work. 

```shell
./deploy.sh -h

OPTIONS:
\n -c {"nats"|"kafka"|"rabbitmq"|"none"}
\t communication tool to deploy.
\n -d {"elasticsearch"|"influxdb"|"none"}
\t database engine to deploy.
\n -p {"openfaas"|"none"}
\t serverless platform to deploy.
\n -g {"kibana"|"none"}
\t GUI/dashboard to deploy.
\n -x {"rb_to_es"| "es_to_rb" | "none"}
\t connectors to deploy.
```

To uninstall everything, run the following script:

```shell
/usr/local/bin/k3s-uninstall.sh
```

## [Option 2] Deploy using vagrant (recommended)

### Prerequisites 

- vagrant
- virtualbox (provider)


### Deployment

Modify Vagrantfile `deploy.sh` script accordingly:

```ruby
config.vm.provision "shell", path: "deploy.sh" 
```

Deploy and connect to the vm:
```shell
vagrant up
vagrant ssh
```
