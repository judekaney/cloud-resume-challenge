# cloud-resume-challenge
This project is my online resume, utilizing HTML, JavaScript, Python, AWS services, and Terraform. 

You can visit my website [here](https://www.judekaney.com).

GitHub Actions and Terraform Cloud act as the CI/CD pipline with automated testing for the Python script that reads and increments the visitor count. 

**How it works:**

Any push to the main branch will trigger GitHub Actions that will:
* Lint the Python script with the Flake8 linting tool, and stop if there are Python syntax errors or undefined names. 
* Run pytest for unit testing. The Lambda function is ran with a mock DynamoDB table and various test events.
* If tests are passed, Terraform Init, Format, Plan, and Apply are then ran to deploy any changes to code or infrastructure. 
