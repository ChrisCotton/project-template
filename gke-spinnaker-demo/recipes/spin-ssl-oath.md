
## SSL for Spinnaker

* [SSL for Spinnaker](#ssl-for-spinnaker)
  * [Prerequisites](#prerequisites)
  * [Create Keys and Certificates](#create-keys-and-certificates)
    * [Create the Certificate Authority (CA) Key](#create-the-certificate-authority-ca-key)
    * [Self-Sign the CA Certificate](#self-sign-the-ca-certificate)
    * [Create the Server Key](#create-the-server-key)
  * [Sign the Key](#sign-the-key)
    * [Create a Signing Request](#create-a-signing-request)
    * [Sign the Request](#sign-the-request)
  * [Import Certificate to Java Keystore (JKS)](#import-certificate-to-java-keystore-jks)
    * [Format Server Certificate](#format-server-certificate)
    * [Create Java Keystore](#create-java-keystore)
    * [Import Server Certificate](#import-server-certificate)
  * [Tell Halyard to use SSL for the Spinnaker API](#tell-halyard-to-use-ssl-for-the-spinnaker-api)
  * [Tell Halyard to use SSL for the Spinnaker UI](#tell-halyard-to-use-ssl-for-the-spinnaker-ui)
  * [Apply Changes](#apply-changes)
  * [Expose the Spinnaker Deck (UI) and Spinnaker Gate (API) services](#expose-the-spinnaker-deck-ui-and-spinnaker-gate-api-services)
  * [Configure DNS to point to your new load balancers](#configure-dns-to-point-to-your-new-load-balancers)
* [OAuth for Spinnaker](#oauth-for-spinnaker)
  * [SSH into your <strong>Halyard host</strong>](#ssh-into-your-halyard-host)
  * [Set up the environment](#set-up-the-environment)
  * [Tell Halyard to allow for OAuth within Spinnaker](#tell-halyard-to-allow-for-oauth-within-spinnaker)
  * [Override the OAuth redirect URLs](#override-the-oauth-redirect-urls)
  * [Tell Halyard to commit the changes to the Spinnaker cluster](#tell-halyard-to-commit-the-changes-to-the-spinnaker-cluster)
  * [Verification](#verification)

These steps will let you configure Spinnaker to serve pages using SSL.  We will
use keys, certificates and signing to enable this.

### Prerequisites
You should have a running Spinnaker instance from following the steps in
[README.md](../README.md).

### Create Keys and Certificates

Run the rest of the instructions on your Halyard VM. *Note:* if you haven't made
a self-signed cert before, make sure you keep track of all of the passwords you
enter in the following steps. It will make your life a lot easier.

```shell
gcloud config set project [YOUR PROJECT ID]
gcloud config set compute/zone us-west1-b # <<-- [OR THE ZONE YOU USED]
gcloud compute ssh halyard-host
```

#### Create the Certificate Authority (CA) Key
```shell
openssl genrsa -des3 -out ca.key 4096
```

#### Self-Sign the CA Certificate
```shell
openssl req -new -x509 -days 365 -key ca.key -out ca.crt
```

#### Create the Server Key

Keep this file safe!

```shell
openssl genrsa -des3 -out server.key 4096
```

### Sign the Key

#### Create a Signing Request

Generate a certificate signing request for the server. Specify `localhost` or
Gate’s eventual fully-qualified domain name (FQDN) as the Common Name (CN).

```shell
openssl req -new -key server.key -out server.csr
```

#### Sign the Request
Use the CA to sign the server’s request. If using an external CA, they will
do this for you.
```shell
openssl x509 -req -days 365 -in server.csr -CA ca.crt -CAkey ca.key \
    -CAcreateserial -out server.crt
```

### Import Certificate to Java Keystore

#### Format Server Certificate

This lets it be imported to JKS.

```shell
YOUR_KEY_PASSWORD=hunter2
openssl pkcs12 -export -clcerts -in server.crt -inkey server.key -out \
    server.p12 -name spinnaker -password pass:$YOUR_KEY_PASSWORD
```

#### Create Java Keystore

```shell
keytool -keystore keystore.jks -import -trustcacerts -alias ca -file ca.crt
```

#### Import Server Certificate
```shell
keytool \
  -importkeystore \
  -srckeystore server.p12 \
  -srcstoretype pkcs12 \
  -srcalias spinnaker \
  -srcstorepass $YOUR_KEY_PASSWORD \
  -destkeystore keystore.jks \
  -deststoretype jks \
  -destalias spinnaker \
  -deststorepass $YOUR_KEY_PASSWORD \
  -destkeypass $YOUR_KEY_PASSWORD
```

### Tell Halyard to use SSL for the Spinnaker API

```shell
KEYSTORE_PATH=keystore.jks

hal config security api ssl edit \
  --key-alias spinnaker \
  --keystore $KEYSTORE_PATH \
  --keystore-password \
  --keystore-type jks \
  --truststore $KEYSTORE_PATH \
  --truststore-password \
  --truststore-type jks

hal config security api ssl enable
```

### Tell Halyard to use SSL for the Spinnaker UI

```shell
SERVER_CERT=server.crt
SERVER_KEY=server.key

hal config security ui ssl edit \
  --ssl-certificate-file $SERVER_CERT \
  --ssl-certificate-key-file $SERVER_KEY \
  --ssl-certificate-passphrase

hal config security ui ssl enable
```

### Apply Changes

Lastly, apply your changes to Halyard.

```shell
hal deploy apply
```

### Expose the Spinnaker Deck (UI) and Spinnaker Gate (API) services

First, we want to reserve static IP addresses.

```shell
REGION=us-west1 # <<-- Or whatever region you've been using
gcloud compute addresses create spin-deck --region $REGION
gcloud compute addresses create spin-gate --region $REGION
```

You can see the newly reserved static IP addresses like this:

```shell
gcloud compute addresses list
```

Now, we're going to expose the UI and API services. You're going to edit each
service inside an editor and change a couple of values and add one. Be sure
you keep the static IP addresses from the above command.

During each of the following `edit svc` commands we will:

1. Change `port: 9000 (or 8084)` to `port: 443`
2. Change `type: ClusterIP` to `type: LoadBalancer`
3. After the line in step 2, add a new line: `loadBalancerIP: xxxx` where
xxxx is replaced with the appropriate static IP from above.

```shell
kubectl edit svc spin-deck -n spinnaker
kubectl edit svc spin-gate -n spinnaker
```

Now you have two load balancers that open https to both the UI and API.

### Configure DNS to point to your new load balancers

**Note:** Here, we expect your DNS to be hosted within a Google Cloud Platform
project. In this example that project name is `yourdomain-shared-services`.

Let's get all of the required variables set up:

```shell
DNS_PROJECT=yourdomain-shared-services
ZONE_NAME=yourdomain-zone # <<-- Replace with yours
DNS_DOMAIN=yourdomain.com # <<-- Replace with yours
REGION=us-west1 # <<-- Replace with yours if you changed it
DNS_NAME_FOR_SPIN_DECK=spin-deck
DNS_NAME_FOR_SPIN_GATE=spin-gate

SPIN_DECK_IP=$(gcloud compute addresses describe spin-deck \
  --region $REGION \
  --format='value(address)')

SPIN_GATE_IP=$(gcloud compute addresses describe spin-gate \
  --region $REGION \
  --format='value(address)')
```

Here, we set up and execute a transaction for modifying the zone file.

```shell
gcloud dns record-sets transaction start \
  --project $DNS_PROJECT \
  -z $ZONE_NAME

gcloud dns record-sets transaction add \
  --name="$DNS_NAME_FOR_SPIN_DECK.$DNS_DOMAIN." \
  --ttl=300 "$SPIN_DECK_IP" \
  --type=A \
  -z $ZONE_NAME

gcloud dns record-sets transaction add \
  --name="$DNS_NAME_FOR_SPIN_GATE.$DNS_DOMAIN." \
  --ttl=300 "$SPIN_GATE_IP" \
  --type=A \
  -z $ZONE_NAME

gcloud dns record-sets transaction execute \
  --project $DNS_PROJECT \
  -z $ZONE_NAME
```

After you execute the transaction, you'll notice that the transaction is
pending. It might take a short while before your DNS changes take effect.

```
Created [https://www.googleapis.com/dns/v1/projects/yourdomain-shared-services/
managedZones/yourdomain-zone/changes/3].
ID  START_TIME                STATUS
3   2018-06-08T16:50:57.812Z  pending
```

If you want to check for status change on the transaction, you can use `dig`.

```shell
dig "$DNS_NAME_FOR_SPIN_DECK.$DNS_DOMAIN"
```

### SSL Validation

Since we're using a self-signed cert, you'll need to add an exception in the web
browser for both the spin-gate and spin-deck subdomains. In a Chrome incognito
window, go to the URL created by this `echo` command:

```shell
echo $DNS_NAME_FOR_SPIN_GATE.$DNS_DOMAIN
```

### SSL Troubleshooting

If you do get an error while executing your DNS transaction, you can abort it
and start over.

```shell
gcloud dns record-sets trasaction abort \
  --project $DNS_PROJECT \
  -z $ZONE_NAME
```

## [OAuth](https://oauth.net/) for Spinnaker

If you use OAuth, authentication to the Spinnaker UI can be accomplished via an
email address from your company's GSuite Organization.

**Note:** If you haven't installed SSL into your Spinnaker installation, you
should follow the below instructions but change the https:// to http:// when you
set the "Authorized redirect URIs".

For this step, you need to follow these
[instructions](https://www.spinnaker.io/setup/security/authentication/oauth/providers/google/)
to get your client ID and client secret.

### SSH into your **Halyard host**

```shell
PROJECT=[YOUR PROJECT THAT CONTAINS YOUR HALYARD MACHINE]
HALYARD_HOST=halyard-host
gcloud config set project $PROJECT
gcloud config set compute/zone us-west1-b
gcloud compute ssh $HALYARD_HOST
```

### Set up the environment

```shell
CLIENT_ID=[FROM THE PROCESS MENTIONED ABOVE]
CLIENT_SECRET=[FROM THE PROCESS MENTIONED ABOVE]
PROVIDER=google
```

### Tell Halyard to allow for OAuth within Spinnaker

```shell
hal config security authn oauth2 edit \
  --client-id $CLIENT_ID \
  --client-secret $CLIENT_SECRET \
  --provider $PROVIDER \
  --user-info-requirements hd=gflocks.com

hal config security authn oauth2 enable
```

### Override the OAuth redirect URLs

https://www.spinnaker.io/reference/halyard/commands/#hal-config-security-ui-edit

```shell
hal config security ui edit \
 --override-base-url https://$DNS_NAME_FOR_SPIN_DECK.$DNS_DOMAIN
 ```

```shell
hal config security api edit \
 --override-base-url https://$DNS_NAME_FOR_SPIN_GATE.$DNS_DOMAIN
```

### Tell Halyard to commit the changes to the Spinnaker cluster

```shell
hal deploy apply
```

### Verification

You can now test the OAuth login. Close all Chrome incognito browser windows
then open a new incognito window.  Navigate to the Spinnaker UI. If you are not
prompted to login, try [clearing your browser history](chrome://settings/clearBrowserData)
for the last hour, or try using a different web browser (Safari, Firefox, etc).
