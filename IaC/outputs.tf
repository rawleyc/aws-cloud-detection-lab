output "pipeline_access_key_id" {
  description = "Access key ID for the pipeline IAM user"
  value       = aws_iam_access_key.pipeline.id
}

output "pipeline_secret_instructions" {
  description = "How to retrieve the secret access key"
  value       = "aws ssm get-parameter --name /detection-lab/pipeline/secret_access_key --with-decryption --query Parameter.Value --output text"
}

output "ec2_public_ip" {
  description = "Public IP of the detection lab EC2 instance"
  value       = aws_instance.test_server.public_ip
}
