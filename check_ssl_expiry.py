import subprocess
import requests
import json
from datetime import datetime, timedelta

def check_ssl_expiry(domain):
    try:
        result = subprocess.run(
            ['openssl', 's_client', '-connect', f'{domain}:443', '-servername', domain],
            stdout=subprocess.PIPE, stderr=subprocess.PIPE, text=True, check=True
        )

        cert_info = result.stdout.split('\n')
        not_after_line = [line for line in cert_info if 'notAfter' in line][0]
        not_after_str = not_after_line.split('=')[1].strip()

        expiry_date = datetime.strptime(not_after_str, '%b %d %H:%M:%S %Y %Z')
        remaining_days = (expiry_date - datetime.utcnow()).days

        return remaining_days

    except subprocess.CalledProcessError:
        return None

def send_slack_alert(domain, remaining_days):
    slack_webhook_url = os.environ.get('SLACK_WEBHOOK_URL')
    if slack_webhook_url:
        message = {
            "text": f"SSL Expiry Alert\n"
                    f"  * Domain: {domain}\n"
                    f"  * Warning: The SSL certificate for {domain} will expire in {remaining_days} days."
        }
        requests.post(slack_webhook_url, data=json.dumps(message), headers={'Content-Type': 'application/json'})

def main():
    domains = ['google.com', 'github.com'] 
    for domain in domains:
        remaining_days = check_ssl_expiry(domain)
        if remaining_days is not None:
            send_slack_alert(domain, remaining_days)

if __name__ == "__main__":
    main()
