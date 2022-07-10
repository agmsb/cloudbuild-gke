from flask import Flask
import os
import random

app = Flask(__name__)
version = 'team_b'
pod = os.getenv('POD')
namespace = os.getenv('NS')
node = os.getenv('NODE')

products = ['BigQuery', 
            'Kubernetes Engine', 
            'Cloud Build', 
            'Cloud Run', 
            'Virtual Private Cloud',
            'Compute Engine', 
            'Cloud Dataflow']

@app.route('/')
def hello_product():
    product = random.choice(products)

    message = (
        "Your Google Cloud product is: {product}! \n\n\n"
        "Built by: {version} \n"
        "You've been served by...\n"
        "Pod: {pod}\n"
        "Running in Namespace: {namespace}\n"
        "Scheduled to Node: {node}\n"
    ).format(version=version, product=product, pod=pod, namespace=namespace, node=node)
    
    response = make_response(message)
    response.headers['content-type'] = 'text/plain'
    return response

if __name__ == '__main__':
    app.run(host='0.0.0.0', port=8080)