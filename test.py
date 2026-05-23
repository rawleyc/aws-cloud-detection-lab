import boto3



ssm = boto3.client("ssm", region_name="eu-central-1")
bucket_name = ssm.get_parameter (
    Name="/logging/flowlogs/bucket"
) ["Parameter"]["Value"]

print(bucket_name)