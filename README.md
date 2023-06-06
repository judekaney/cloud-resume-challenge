# cloud-resume-challenge
This project is my online resume, utilizing HTML, JavaScript, Python, AWS services, and Terraform. GitHub Actions and Terraform Cloud act as the CI/CD pipline with automated testing for the Python script used to read and increment the visitor count. 


> You can visit my website [here](https://www.judekaney.com)!

## Architecture

![judekaney com-diagram](https://github.com/judekaney/resume-gitactions/assets/111720701/ea20e062-f805-4b2b-89e3-0069203c8c26)



## How it works:

#### Any push to the main branch will trigger GitHub Actions that will:
* Lint the Python script with the Flake8 linting tool, and stop if there are Python syntax errors or undefined names
* Run pytest for unit testing. The Lambda function is run with a mock DynamoDB table and various test events
* If tests are passed, Terraform Init, Format, Plan, and Apply are then run to deploy any changes to code or infrastructure

**A basic overview functionality:** 
* A S3 bucket hosts the website
* CloudFront is used for content distribution
* The DNS hosted zone is configured in Route53
* The SSL certificate is provided by ACM 
* JavaScript is used to retrieve the visitor counter via an API
* API Gateway is used to implement the API endpoint
* A Lambda function increments and returns the visitor count
* DynamoDB stores the visitor count 

