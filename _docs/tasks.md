# Project Backlog

## 1. Set up an empty project with a passing test
Goal: Create the minimal repository structure and prove the test command succeeds.
Description: Add empty directories for scripts, configuration, dashboards, and tests, plus a short README explaining the project layout. Provide a dependency-light smoke test and a single documented command that runs it successfully without creating AWS resources.

## 2. Define and validate project prerequisites
Goal: Document required inputs and fail early when the local machine or AWS account is not ready for provisioning.
Description: Create an example environment/configuration file covering AWS region, AMI ID, instance type, subnet, key pair, administrator CIDR, and resource prefix, with validation rules and guidance that credentials must not be stored in it. Add a read-only preflight command that checks local tools, AWS CLI authentication, and the selected AWS resources, plus automated tests using fixtures or mocks so the test suite does not contact AWS.

## 3. Define monitoring-environment network access
Goal: Create security groups that expose administration interfaces narrowly and permit private Node Exporter scraping.
Description: Add idempotent AWS CLI commands that create a Prometheus server security group allowing ports 22, 9090, and 3000 only from the administrator CIDR, and a target security group allowing SSH from that CIDR and port 9100 only from the server security group. Capture both security group IDs and include read-only checks proving that Node Exporter is not exposed to `0.0.0.0/0` or `::/0`.

## 4. Provision, tag, and inventory the four EC2 instances
Goal: Launch the complete EC2 topology with predictable identities and the correct discovery tags.
Description: Add AWS CLI commands that launch the Prometheus server, static target, and two dynamic targets using the documented inputs and appropriate security groups, wait for them to run, and apply distinct `Name` tags. Apply `PrometheusTarget=true` only to the two dynamic targets, record instance IDs and private IP addresses in a secret-free local inventory, and add checks that fail on missing or unintended discovery tags.

## 5. Create the least-privilege EC2 discovery IAM resources
Goal: Give the Prometheus server permission to discover EC2 instances without access keys.
Description: Add the custom policy document, EC2 trust policy, role, and instance-profile commands required for `ec2:DescribeInstances`. Attach the profile only to the Prometheus server and verify both the attachment and the absence of embedded AWS credentials in project artifacts.

## 6. Install Prometheus with healthy self-scraping
Goal: Run a pinned Prometheus release as an enabled systemd service whose self-target is healthy.
Description: Add server-side commands that verify the download, create a non-login service user, install the files in appropriate Linux directories, and register `prometheus.service`. Supply an initial `prometheus.yml` containing only the local port 9090 job, validate it with `promtool`, and document checks for systemd status, logs, readiness, the targets API, and `up{job="prometheus"} == 1`.

## 7. Install Node Exporter as a systemd service
Goal: Provide a reusable installation procedure for each of the three target instances.
Description: Add target-side commands that verify a pinned Node Exporter download, create a non-login service user, install the binary, and register an enabled `node_exporter.service`. Include local checks for systemd status, startup logs, and the metrics endpoint on port 9100, and explain how to apply the same procedure independently to all three targets.

## 8. Add and validate the static Node Exporter target
Goal: Configure Prometheus to scrape the static target over its private IP address.
Description: Extend the Prometheus configuration with a `node-static` job whose address comes from the generated inventory. Validate the configuration before activation and document checks proving the target is `UP` and exposes a representative Node Exporter metric.

## 9. Add and validate tag-filtered EC2 service discovery
Goal: Discover only running EC2 instances tagged `PrometheusTarget=true` in the Prometheus server's region.
Description: Add the `node-ec2-discovery` job with region selection, running-state and tag filters, and relabeling that builds `<private-ip>:9100`, while preserving useful labels such as instance ID and `Name`. Validate the configuration with `promtool` and document checks proving that exactly the two dynamic targets appear and are `UP`.

## 10. Verify discovery updates and service persistence
Goal: Prove EC2 discovery responds to tag changes and Node Exporter survives a target reboot.
Description: Write a reversible procedure that removes the discovery tag from one dynamic target, confirms that it disappears after the refresh interval, and restores the tag before verifying its return. Reboot one target and confirm that the enabled Node Exporter service starts automatically and the target becomes `UP` again.

## 11. Install Grafana and connect it to Prometheus
Goal: Run Grafana as an enabled systemd service with a working local Prometheus data source.
Description: Add commands for configuring Grafana's official RPM repository, installing the package, and enabling and starting `grafana-server`, with service, log, port 3000, and browser checks. Provide reproducible UI or provisioning steps for a Prometheus data source at `http://localhost:9090`, verify it with a simple query, and explain how to handle first-login credentials without committing secrets.

## 12. Import and validate a Node Exporter dashboard
Goal: Display metrics for all three target instances in a maintained community dashboard.
Description: Document the selected dashboard ID and compatible revision, its required data source mapping, and the import steps. Verify that the static target and both dynamically discovered targets are selectable and that key panels contain data.

## 13. Build and export the custom host-utilization dashboard
Goal: Create an importable dashboard with per-instance CPU, memory, and root-filesystem utilization.
Description: Build three Grafana time-series panels using the PromQL defined in `_docs/plan.md`, an `{{instance}}` legend, percentage units, and a 0-to-100 range, then confirm that every panel shows all three targets. Export the dashboard as version-controlled JSON with environment-specific identifiers removed, re-import it, and verify that the restored dashboard remains functional.

## 14. Add end-to-end validation and troubleshooting guidance
Goal: Provide one repeatable checklist that proves every project completion criterion and diagnoses common failures.
Description: Add non-destructive checks with expected results for security groups, IAM attachment, systemd enablement, private-IP scrape health, discovery behavior, Grafana connectivity, and both dashboards, plus focused troubleshooting commands for AWS, networking, configuration, and service logs. Define sanitized screenshot or text evidence for the EC2 inventory, service status, Prometheus targets, and Grafana dashboards, and include operating notes for stopping or terminating billable resources and repeating validation after changes.
