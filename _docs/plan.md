# Manual Prometheus Installation on Four EC2 Instances

## Objective

Manually build a small Prometheus monitoring environment on AWS EC2 and learn both static target configuration and EC2 service discovery.

## Architecture

| EC2 instance | Purpose | Software |
| --- | --- | --- |
| `prometheus-server` | Collects metrics and hosts both web interfaces | Prometheus and Grafana |
| `static-target` | Target configured manually in `prometheus.yml` | Node Exporter |
| `dynamic-target-1` | Discovered automatically through the AWS EC2 API | Node Exporter |
| `dynamic-target-2` | Discovered automatically through the AWS EC2 API | Node Exporter |

The user will provide the AMI, and all four instances will be created with AWS CLI commands in the same AWS region and VPC.

## Agreed Decisions

- Use private IP addresses for Prometheus scraping.
- Provision and tag the four EC2 instances using the AWS CLI rather than the AWS Console.
- Install Node Exporter on all three target instances.
- Install Prometheus only on the Prometheus server.
- Run Prometheus and Node Exporter as `systemd` services managed with `systemctl`.
- Configure one Node Exporter instance as a static target.
- Discover the other two targets through EC2 service discovery.
- Scan the Prometheus server's own AWS region.
- Select dynamic targets using an EC2 tag such as `PrometheusTarget=true`.
- Give the Prometheus server an EC2 instance role; do not store AWS access keys on it.
- Use a least-privilege custom IAM policy rather than `AmazonEC2ReadOnlyAccess`.
- View target health and query metrics from the Prometheus server UI.
- Install Grafana on the Prometheus server from its official RPM repository.
- Run Grafana through its packaged `grafana-server` systemd service.
- Add Prometheus in Grafana as a data source using `http://localhost:9090`.
- Import a ready-made Node Exporter dashboard.
- Create a separate custom dashboard with per-instance CPU, memory, and root-filesystem utilization time-series panels.
- Defer Grafana alerts and Alertmanager to a later phase.

## Networking and Security Groups

- Prometheus UI listens on TCP port `9090`.
- Grafana listens on TCP port `3000`.
- Node Exporter listens on TCP port `9100`.
- Allow the Prometheus server to reach port `9100` on the three target instances over their private IP addresses.
- Restrict port `9100` so it is not publicly accessible.
- Permit browser access to port `9090`, preferably only from the administrator's public IP.
- Permit access to Grafana port `3000` only from the administrator's public IP.
- Allow SSH port `22` only from the administrator's public IP for manual installation.

The scrape configuration identifies the targets, while security groups permit the actual network connections.

## IAM Scope

Create a custom IAM policy for EC2 discovery and attach it to an IAM role assigned to the Prometheus server.

Minimum intended permission:

```json
{
  "Version": "2012-10-17",
  "Statement": [
    {
      "Effect": "Allow",
      "Action": "ec2:DescribeInstances",
      "Resource": "*"
    }
  ]
}
```

`Resource` must be `*` because the EC2 `DescribeInstances` action does not support resource-level permissions. If Prometheus or the AWS SDK reports additional required read-only describe actions during implementation, add only those actions.

## Installation Scope

### AWS infrastructure

- Use AWS CLI commands to create the required security groups and rules.
- Launch all four EC2 instances with the user-provided AMI, selected instance type, subnet, security groups, and SSH key pair.
- Apply distinct `Name` tags to identify the Prometheus server, static target, and two dynamic targets.
- Apply `PrometheusTarget=true` only to the two dynamically discovered targets.
- Capture the returned instance IDs and private IP addresses for later configuration and validation.

### Prometheus server

- Download and extract a selected Prometheus release manually.
- Create a dedicated Prometheus system user.
- Place binaries, configuration, console assets, and data in appropriate Linux directories.
- Create a `systemd` unit for Prometheus.
- Enable and start it with `systemctl`.
- Verify the service status and logs.

### Three target instances

- Download and extract a selected Node Exporter release manually.
- Create a dedicated Node Exporter system user.
- Install the Node Exporter binary.
- Create a `systemd` unit.
- Enable and start it with `systemctl`.
- Confirm that metrics are exposed on port `9100`.

## Prometheus Configuration

The final `prometheus.yml` will contain three scrape jobs:

1. `prometheus` — scrapes the Prometheus server itself on port `9090`.
2. `node-static` — contains the static target's private IP and port `9100`.
3. `node-ec2-discovery` — uses `ec2_sd_configs` in the server's AWS region and keeps running EC2 instances tagged `PrometheusTarget=true`.

Relabeling will build each discovered target address from its private IP plus port `9100`. Useful EC2 metadata, such as the instance ID and Name tag, may be copied into Prometheus labels.

Only the two dynamic nodes should receive the discovery tag. The Prometheus server and static target should not receive it, preventing duplicate or unintended targets.

## Grafana Configuration

Grafana will be installed on the same EC2 instance as Prometheus through the official RPM repository. The RPM package supplies the `grafana-server` systemd unit. Grafana will be enabled and started with `systemctl`.

In Grafana, add a Prometheus data source with:

- Type: `Prometheus`
- URL: `http://localhost:9090`
- Access: server-side/default

After the connection test succeeds:

1. Import a compatible Node Exporter dashboard from the Grafana dashboard catalog.
2. Create a custom dashboard containing three time-series panels.
3. Display a separate series for every EC2 target using the `instance` label.
4. Use a percentage unit and an appropriate `0` to `100` range for all panels.

### Custom Dashboard PromQL

CPU utilization percentage, calculated as 100% minus idle CPU time:

```promql
100 - (
  avg by (instance) (
    rate(node_cpu_seconds_total{
      job=~"node-static|node-ec2-discovery",
      mode="idle"
    }[5m])
  ) * 100
)
```

Memory utilization percentage, using available memory rather than only free memory:

```promql
100 * (
  1 -
  node_memory_MemAvailable_bytes{
    job=~"node-static|node-ec2-discovery"
  }
  /
  node_memory_MemTotal_bytes{
    job=~"node-static|node-ec2-discovery"
  }
)
```

Root-filesystem utilization percentage:

```promql
100 * (
  1 -
  node_filesystem_avail_bytes{
    job=~"node-static|node-ec2-discovery",
    mountpoint="/",
    fstype!~"tmpfs|overlay|squashfs"
  }
  /
  node_filesystem_size_bytes{
    job=~"node-static|node-ec2-discovery",
    mountpoint="/",
    fstype!~"tmpfs|overlay|squashfs"
  }
)
```

Use `{{instance}}` as the Grafana legend for each query. The custom dashboard will also be exported as an importable JSON artifact.

## Implementation and Validation Sequence

1. Create security groups and launch the four EC2 instances with the AWS CLI.
2. Configure security groups and private connectivity.
3. Install Prometheus and register it as a `systemd` service.
4. Start Prometheus and verify its self-target using the `up` query; expected value: `1`.
5. Install Node Exporter on the static target and register it with `systemd`.
6. Add the static target to `prometheus.yml`, reload or restart Prometheus, and verify that it is `UP`.
7. Install and start Node Exporter on the two dynamic targets.
8. Tag both dynamic instances with `PrometheusTarget=true`.
9. Create the least-privilege IAM policy and role, then attach the role to the Prometheus server.
10. Add EC2 service discovery and tag-based relabeling to `prometheus.yml`.
11. Reload or restart Prometheus and verify that both dynamic targets appear as `UP`.
12. Query `up` and Node Exporter metrics in the Prometheus UI.
13. Reboot one target to confirm Node Exporter starts automatically through `systemd`.
14. Install Grafana from its official RPM repository on the Prometheus server.
15. Enable and start `grafana-server` with `systemctl`.
16. Open Grafana on port `3000` and add `http://localhost:9090` as the Prometheus data source.
17. Import a Node Exporter dashboard and confirm all three targets appear.
18. Build the custom CPU, memory, and root-disk time-series panels with the agreed PromQL.
19. Export the custom Grafana dashboard as JSON and verify that it can be imported.

## Completion Criteria

The project is complete when:

- Prometheus starts automatically and is active under `systemctl`.
- Node Exporter starts automatically on all three target instances.
- The Prometheus self-target is `UP`.
- The manually configured static target is `UP`.
- Both tag-filtered dynamic targets are discovered automatically and are `UP`.
- Prometheus scrapes all target nodes through private IP addresses.
- Removing the discovery tag causes a dynamic target to disappear after the discovery refresh interval.
- No long-lived AWS access keys are stored on any EC2 instance.
- Grafana runs as an active, enabled `systemd` service.
- Grafana successfully connects to Prometheus through `http://localhost:9090`.
- The imported Node Exporter dashboard displays all three EC2 targets.
- The custom dashboard displays separate CPU, memory, and root-disk time series for every target.
- The custom dashboard can be exported and re-imported as JSON.

## Ordered Output Artifacts

The implementation deliverables will be prepared in this order:

1. AWS CLI script or ordered commands for security groups, EC2 creation, and tagging
2. Least-privilege EC2 discovery IAM policy JSON
3. Prometheus installation commands and `prometheus.service`
4. Initial self-scrape `prometheus.yml`
5. Node Exporter installation commands and `node_exporter.service`
6. Static-target version of `prometheus.yml`
7. Final tag-filtered EC2 service-discovery `prometheus.yml`
8. Prometheus and Node Exporter validation commands
9. Official RPM-based Grafana installation and `systemctl` steps
10. Grafana Prometheus data-source configuration steps
11. Node Exporter dashboard import steps
12. CPU, memory, and root-filesystem PromQL queries
13. Importable custom Grafana dashboard JSON
14. End-to-end validation checklist and troubleshooting commands
15. Screenshots captured at useful validation milestones, when needed

## Optional Screenshot Evidence

Screenshots may be captured as supporting artifacts whenever they help demonstrate a completed milestone. Useful evidence includes:

- AWS CLI output showing the four instance IDs and private IP addresses
- `systemctl status prometheus`
- `systemctl status node_exporter`
- `systemctl status grafana-server`
- Prometheus **Status > Targets** showing the self, static, and dynamic targets as `UP`
- Grafana Prometheus data-source connection test
- Imported Node Exporter dashboard
- Custom CPU, memory, and root-filesystem dashboard

Screenshots are supporting evidence; configuration files, commands, service units, policies, queries, and dashboard JSON remain the reproducible source artifacts.

## Out of Scope

- Terraform, CloudFormation, or other infrastructure-as-code provisioning
- Creating EC2 instances manually through the AWS Console
- Ansible or automated software installation
- Alertmanager and alert notifications
- Grafana alert rules and notification channels
- HTTPS, authentication, reverse proxies, or public production exposure
- High availability, clustering, and long-term remote storage
- Kubernetes monitoring

## Inputs Needed During Implementation

- AMI ID or selected AMI
- AWS region and VPC/subnets
- EC2 instance type
- SSH key pair
- Administrator public IP for restricted SSH and UI access
- Prometheus and Node Exporter versions
