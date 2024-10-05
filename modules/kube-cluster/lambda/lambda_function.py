import subprocess
import json
import os
import boto3
import logging

logger = logging.getLogger()
logger.setLevel(logging.INFO)

def get_private_dns_name(instance_id):
    ec2_client = boto3.client('ec2')
    response = ec2_client.describe_instances(InstanceIds=[instance_id])
    private_dns_name = response['Reservations'][0]['Instances'][0]['PrivateDnsName']
    return private_dns_name

def get_kubeconfig():
    client = boto3.client('secretsmanager')
    secret_value = client.get_secret_value(SecretId='REPLACE_WITH_KUBE_CONF_SECRET_NAME')
    kubeconfig = secret_value['SecretString']
    # Save the kubeconfig to a temporary file for use with kubectl
    with open('/tmp/kubeconfig', 'w') as f:
        f.write(kubeconfig)
    return '/tmp/kubeconfig'

def lambda_handler(event, context):
    # Extract the instance ID from the ASG termination event
    message = json.loads(event['Records'][0]['Sns']['Message'])
    instance_id = message['EC2InstanceId']

    # Get the private DNS name of the instance (used as the Kubernetes node name)
    node_name = get_private_dns_name(instance_id)
    logger.info(f"Private DNS Name of the instance {instance_id}: {node_name}")

    os.environ['KUBECONFIG'] = get_kubeconfig()

    env = os.environ.copy()

    try:
        # Drain the node
        logger.info(f"Draining node {node_name}")
        drain_cmd = f"kubectl drain {node_name} --ignore-daemonsets --delete-emptydir-data --force"
        subprocess.run(drain_cmd, shell=True, check=True, env=env)
        logger.info(f"Node {node_name} drained successfully")

        # Delete the node
        logger.info(f"Deleting node {node_name}")
        delete_cmd = f"kubectl delete node {node_name}"
        subprocess.run(delete_cmd, shell=True, check=True, env=env)
        logger.info(f"Node {node_name} deleted successfully")

        # Clean up kubeconfig file
        os.remove('/tmp/kubeconfig')

        return {
            'statusCode': 200,
            'body': f"Node {node_name} successfully deregistered from the Kubernetes cluster."
        }

    except subprocess.CalledProcessError as e:
        logger.error(f"Error draining and deleting node {node_name}: {str(e)}")
        return {
            'statusCode': 500,
            'body': f"Error draining and deleting node {node_name}: {str(e)}"
        }
