NAMESPACE=$1
API_NAME=$2
COMPARTMENT_ID=$3
GATEWAY_ID=$4
API_DESCRIPTION=$5
PATH_PREFIX=$6
SPEC_FILE=$7


INGRESS_DOMAIN_NAME=`kubectl get ingress -n $NAMESPACE  --no-headers | awk '{ print $3}'`



echo "Preparing the spec file"

if [[ -z "$INGRESS_DOMAIN_NAME" ]]; then
    echo "Ingress domain name is empty"
    exit 1
else
    sed -i "s,{{SERVER_HTTPS_DNS}},http://$INGRESS_DOMAIN_NAME," $SPEC_FILE
    echo "Spec file is ready"
fi

API_ID=`oci api-gateway api list --compartment-id=$COMPARTMENT_ID --display-name=$API_NAME`

if [[ -z "$API_ID" ]]; then
	echo "api not present hence creating"
	oci api-gateway api create --display-name $API_NAME --compartment-id $COMPARTMENT_ID --content $API_DESCRIPTION
	echo "api is created"
fi

DEPLOYMENT_ID=`oci api-gateway deployment list --compartment-id $COMPARTMENT_ID --lifecycle-state ACTIVE --query 'data.items[*].{API_NAME:"display-name",ID:"id"}' --output json | jq -r --arg api "$API_NAME" '.[] | select(.API_NAME == $api) | .ID'`

if [[ -z "$DEPLOYMENT_ID" ]]; then
	echo "Deployment is not present, hence creating the deployment..."
	oci api-gateway deployment create --compartment-id $COMPARTMENT_ID --display-name $API_NAME --gateway-id $GATEWAY_ID --path-prefix "$PATH_PREFIX" --specification file://$SPEC_FILE
	
	echo "Deployment created successfully..."
else
	echo "Deployment is present, modifying it according to the spec file passed"
	oci api-gateway deployment update --deployment-id $DEPLOYMENT_ID  --specification file://$SPEC_FILE --force
	
	echo "Deployment modified successfully"

fi
