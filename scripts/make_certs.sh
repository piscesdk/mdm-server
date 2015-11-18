#!/bin/bash -e

pushd `dirname $0`

echo ""
if [ "$#" -ne 1 ]; then
    echo "Please enter the Hostname or IP address of your server."
    read IP
else
    IP=$1
fi

echo "Setting up server.cnf."
sed -e "s/<SERVER_IP>/$IP/g" server.cnf.template > server.cnf
echo "Done."

echo ""
echo "Setting up certificates for MDM server testing!"
echo ""
echo "1. Creating Certificate Authority (CA)"
openssl req -new -x509 -extensions v3_ca -keyout cakey.key -out cacert.crt -days 365 -nodes -subj "/C=US/ST=CA/L=Springfield/O=Dis/CN=MDM CA"

echo ""
echo "2. Creating the Web Server private key and certificate request"
openssl genrsa 2048 > server.key
openssl req -new -key server.key -out server.csr -subj "/C=US/ST=CA/L=Springfield/O=Dis/CN=$IP" 

echo ""
echo "3. Signing the server key with the CA."
openssl x509 -req -days 365 -in server.csr -CA cacert.crt -CAkey cakey.key -CAcreateserial -out server.crt -extfile ./server.cnf -extensions ssl_server

echo ""
echo "4. Creating the device Identity key and certificate request"
openssl genrsa 2048 > identity.key
openssl req -new -key identity.key -out identity.csr -subj "/C=US/ST=CA/L=Springfield/O=Dis/CN=device cert"

echo ""
echo "5. Signing the identity key with the CA."
openssl x509 -req -days 365 -in identity.csr -CA cacert.crt -CAkey cakey.key -CAcreateserial -out identity.crt
openssl pkcs12 -export -out identity.p12 -inkey identity.key -in identity.crt -certfile cacert.crt -passout pass:123456

echo ""
echo "6. Copying keys and certs to server folder."
# Move relevant certs to the /server/ directory
mv server.key ../server/Server.key
mv server.crt ../server/Server.crt
mv cacert.crt ../server/CA.crt
mv identity.crt ../server/identity.crt
cp identity.p12 ../server/Identity.p12

DEVICE_CERT=`base64 -i ./identity.p12`
sed -e "s/<IDENTITY_P12>/$(echo $DEVICE_CERT | sed -e 's/\\/\\\\/g' -e 's/\//\\\//g' -e 's/&/\\\&/g')/g" Enroll.mobileconfig.template | sed "s/<SERVER_IP>/$IP/g" > ../server/Enroll.mobileconfig

echo "7. Copying PUSH certificate to server folder."
cp PushCert.pem ../server/
