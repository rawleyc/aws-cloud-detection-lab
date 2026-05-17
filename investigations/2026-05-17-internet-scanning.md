# Investigation Report: Opportunistic Internet Scanning
**Date:** 2026-05-17  
**Analyst:** Rawley Chirume  
**Severity:** MEDIUM  
**Status:** Closed — No Action Required  
**Detection Rule:** Port scan detected (T1046 - Network Service Discovery)

---

## Executive Summary

Within approximately 3 hours of an EC2 instance (`172.31.2.25`, `eu-central-1`) being assigned a public IP address, the VPC Flow Logs pipeline detected port scanning activity from 6 distinct external IP addresses. None of these scans were initiated by the lab operator. All traffic was rejected by the instance security group. No successful connections were made.

The activity is consistent with automated opportunistic internet scanning — a background noise phenomenon affecting all publicly routable IP addresses. No targeted attack is indicated. The instance was not compromised.

---

## Detection

**Rule triggered:** `detect_port_scan` — fires when a single source IP attempts connections to 15 or more distinct destination ports on the same target within the log collection window.

**Raw finding summary:**

| Source IP | Rejected Ports | Country | Classification |
|-----------|---------------|---------|----------------|
| 51.159.110.167 | 196 | France | Known malicious scanner |
| 5.61.209.224 | 83 | Russia | Automated scanner |
| 79.124.58.162 | 15 | Bulgaria | Automated scanner |
| 78.128.114.50 | 16 | Czech Republic | Automated scanner |
| 45.142.193.169 | 25 | Romania | Known malicious scanner |
| 104.248.197.12 | 20 | USA (DigitalOcean) | Cloud-hosted scanner |

Note: `79.184.227.217` (590 rejected ports) is the lab operator's own nmap test and is excluded from this investigation.

---

## IP Intelligence

### 51.159.110.167 — Scaleway, Paris, France
- **ASN:** AS12876
- **Hostname:** `7ed7725f-5ec3-47fd-912a-0e158b7f5e16.fr-par-2.baremetal.scw.cloud`
- **Blacklists:** AbuseIPDB, CI Army (Collective Intelligence Network Security)
- **DShield:** 899 reports against 263 distinct targets on a single day (2025-12-23/24); 794 reports against 627 targets on 2025-12-31
- **Shodan:** Open ports 22, 80. Running Nginx 1.14.2, OpenSSH 7.9p1 on Debian Linux. Tagged `eol-product` — end-of-life software stack, consistent with a compromised or deliberately configured attack host.
- **Assessment:** High-confidence malicious scanner. Consistent long-term presence on multiple threat feeds. The EOL software tag suggests this host is either intentionally running outdated software or has been compromised and repurposed. 196 ports probed against this instance.

### 45.142.193.169 — LLC Digital Network / Skynet Network, Romania
- **ASN:** AS214295
- **Network:** 45.142.193.128/27
- **Blacklists:** AbuseIPDB, IPsum Threat Intelligence feed
- **Malwarebytes:** Explicitly blocked as a port scanner involved in RDP probing and ransomware pre-positioning activity. Malwarebytes notes these IPs scan IP ranges then attempt brute-force access to deploy ransomware.
- **Assessment:** High-confidence malicious scanner with documented ransomware pre-positioning behaviour. The /27 subnet (45.142.193.128-159) has multiple IPs with abuse reports, suggesting the entire block is used for scanning infrastructure. 25 ports probed.

### 104.248.197.12 — DigitalOcean, New York, USA
- **ASN:** AS14061 (DigitalOcean-ASN)
- **Assessment:** DigitalOcean is a well-documented source of scanning and attack traffic due to the ease of spinning up cheap VPS instances. The IP is likely a rented droplet running automated scanning tools. DigitalOcean abuse is endemic enough that it appears in multiple threat intelligence reports as a top attacking ASN globally. 20 ports probed.

### 5.61.209.224, 79.124.58.162, 78.128.114.50
- Eastern European IP ranges (Russia, Bulgaria, Czech Republic) with small scan footprints (15-83 ports). Consistent with automated internet-wide scanners cycling through IP ranges. Low individual significance but collectively confirm this instance was added to active scan lists within hours of receiving its public IP.

---

## Traffic Analysis

All 6 external scanners targeted `172.31.2.25` — the private IP of the EC2 instance, mapped to its public Elastic IP. All connections were recorded with `action: REJECT` in the VPC Flow Logs, confirming the security group denied every attempt before reaching the instance OS.

**Protocol:** All TCP (protocol 6), consistent with SYN-scan methodology (nmap default, masscan, zmap).

**Port targeting patterns:** The scans covered a wide range of ports with no single dominant target port visible in the 15-83 port range scans. The 196-port scan from `51.159.110.167` likely represents a more comprehensive sweep of common service ports (SSH, RDP, SMB, HTTP, HTTPS, database ports, etc.).

**Timing:** All scans occurred within the first 3 hours of the instance being live. This is expected — internet-wide scanners (Shodan, Censys, and malicious equivalents) complete full IPv4 sweeps in under an hour using tools like masscan. A new public IP is typically discovered and probed within minutes to hours.

---

## Assessment

**Threat level:** LOW — No successful connections. No evidence of exploitation attempts beyond initial scanning. Standard background internet noise.

**Is this targeted?** No. The scan patterns, timing, and source diversity are consistent with automated opportunistic scanning, not a targeted attack. The instance has no public-facing services (all ports rejected), so there is nothing to exploit even if a scanner finds the IP.

**Is the instance compromised?** No. All traffic was rejected at the security group layer. The instance OS never processed any of these connection attempts.

**Why did this happen so fast?** Internet-wide scanning is continuous. Tools like masscan can scan the entire IPv4 address space in under 6 minutes. When a new IP is assigned, it enters the scan rotation immediately. This is not abnormal — it happens to every public IP address.

---

## Response

**Action taken:** None required. Security group is correctly configured — all inbound ports except SSH (port 22, restricted to operator IP) are denied by default.

**Recommended hardening (optional):**
1. Add the confirmed malicious IPs to an explicit security group deny rule for documentation purposes, though the default-deny posture already blocks them.
2. Consider restricting SSH to a specific CIDR rather than a single IP if the operator's IP changes frequently.
3. If the instance is not actively in use, stop it to eliminate the public IP and associated scan surface.

**No escalation required.**

---

## Lessons Learned

**On detection:** The port scan rule correctly identified all 6 external scanners using a threshold of 15 rejected ports from a single source. The threshold is appropriate — it filters single-port probes (common) while catching systematic scans. Zero false positives from legitimate traffic.

**On alert fatigue:** Without the deduplication logic applied to the root account rule earlier in this project, a naive implementation would have generated 6 separate HIGH alerts with identical context. Grouping by source IP and reporting port counts rather than individual connection records is the correct approach for this rule type.

**On the value of Flow Logs:** This investigation was only possible because VPC Flow Logs captured rejected traffic. CloudTrail alone would have shown nothing — these were network-layer probes, not API calls. The combination of both log sources is essential for complete visibility.

**On false positives:** `79.184.227.217` (590 ports) triggered the same rule as the malicious scanners. This is the operator's own nmap test and would need to be suppressed in a production environment via an allowlist or by correlating with a known-good IP list. Documenting the intentional test as part of the lab setup is sufficient here.

---

## IOCs

| Indicator | Type | Confidence | Notes |
|-----------|------|------------|-------|
| 51.159.110.167 | IPv4 | High | AbuseIPDB + CI Army listed, EOL software stack |
| 45.142.193.169 | IPv4 | High | Malwarebytes-blocked, RDP/ransomware pre-positioning |
| 104.248.197.12 | IPv4 | Medium | DigitalOcean-hosted scanner |
| 5.61.209.224 | IPv4 | Medium | Eastern European scanner |
| 79.124.58.162 | IPv4 | Medium | Eastern European scanner |
| 78.128.114.50 | IPv4 | Medium | Eastern European scanner |

---

## References

- AbuseIPDB: https://www.abuseipdb.com
- NERD CESNET Threat Intelligence: https://nerd.cesnet.cz
- Malwarebytes Threat Center: https://www.malwarebytes.com/blog/detections/45-142-193-169
- MITRE ATT&CK T1046: https://attack.mitre.org/techniques/T1046/
- DShield / SANS Internet Storm Center: https://isc.sans.edu