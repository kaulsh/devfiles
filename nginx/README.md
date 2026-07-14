# NGINX Setup

## Layout

The below layout displays the location of important configurations required for configuration of this nginx server along with it's ssl/tls certificate server blocks.

```txt
etc 
├── nginx
│   ├── conf.d
│   │   └── domain.tld.conf
|   |   └── ... and more
│   └── ssl
│       ├── ssl.conf
│       ├── dhparam.pem # generated, see installation
│       ├── fullchain.crt # generated, see installation
│       └── crt.key # generated, see installation
```

# Installation (Wildcard certificate method)

### **Note: The below api is specific to DigitalOcean. You can check other [acme.sh compatible api here](https://github.com/acmesh-official/acme.sh/wiki/dnsapi)**

### 1) Install acme.sh

### 2) Get your DigitalOcean API key

```bash
// add to .bashrc
export DO_API_KEY="e63f24889...the.rest.of.your.key"
```

### 3) Generate dhparam (this will take some time)

```bash
openssl dhparam -out /etc/nginx/ssl/dhparam.pem 2048
```

### 4) Fetch and install your certs

In the following, use `*.DOMAIN.TLD` to issue and install wildcard cert. Repeat `-d` for multiple domains.

```bash
# You might want to use your DNS provider's acme.sh plugin in place of dns_dgon, which is for DigitalOcean
acme.sh --issue --dns dns_dgon -d <DOMAIN.TLD>

sudo acme.sh --install-cert -d <DOMAIN.TLD> --key-file /etc/nginx/ssl/cert.key --fullchain-file /etc/nginx/ssl/fullchain.crt
```

