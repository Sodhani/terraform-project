# terraform-project
This project is to deploy a multi-tenant SaaS application on AWS using terraform.

The requirement mentioned was for a SaaS application infrstraucture deployment on AWS, supporting multi-tenant deployments.
The AWS services mentioned to be used were
  - Cloudfront
  - Database (RDS)
  - IAM roles
  - ECS
  - Security Groups

The terraform code submitted will deploy a SaaS application in AWS where we have 2 tenants (tenant1 and tenant3) sharing an environment for the deployed application and another tenant (tenant2) having the application deployed in a separate environment  

High Level Diagram
![Terraform_Project_Diagram](https://github.com/Sodhani/terraform-project/blob/main/Terraform_Project_Diagram.jpg)

Multi-tenancy has been obtained, by separating the tenants based on the subdomain of the dummy web application deployed.
The domain on which the application is deployed is "sodhani.xyz" and we have tenants separated logically as "tenant1.sodhani.xyz", "tenant2.sodhani.xyz" and "tenant3.sodhani.xyz"

Pre-requisite: Create a hosted zone for the domain in use and setup the ACM certificates, and export the AWS_ACCESS_KEY_ID and AWS_SECRET_ACCESS_KEY in the terminal. 

To setup this infrastructure, please follow the below steps:

To create the docker image and push to ECR:
1. Under terraform-project/create_ecr/ edit the vars.tf and run "terraform init" and "terraform apply". This will create the ECR, and output the ECR URL
2. Under terraform-project/nodeJS_App, we will build the docker image and push it to the above ECR
    - docker build -t <ECR_URL>:1 .
    - aws ecr get-login (Copy the output and run it on the terminal)
    - docker push <ECR_URL>:1

To run the project
1. Under terraform-project/deployment/, update the variables.json file with the URL to the docker image created earlier in ECR
2. Update the s3 backed value to store the terraform state in main.tf under terraform-project/deployment 
3. Run "terraform init" and "terraform apply -var-file=./variables.json" and confirm "yes"
4. Once the infrastructure is ready, access the domain (sodhani.xyz) which will land on the static page available in the s3 bucket called via cloudfront and access the tenants (tenant1.sodhani.xyz, tenant2.sodhani.xyz and tenant3.sodhani.xyz) which will return a "Hello World!!" from the dummy application.


