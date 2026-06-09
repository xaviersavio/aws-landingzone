# AWS Landing Zone — Architecture Diagrams

---

## 1. AWS Organization Structure

```mermaid
graph TD
    Root["🏢 Root\n(Management Account)"]

    Root --> SecurityOU["📁 Security OU"]
    Root --> InfraOU["📁 Infrastructure OU"]
    Root --> WorkloadsOU["📁 Workloads OU"]
    Root --> SandboxOU["📁 Sandbox OU"]

    SecurityOU --> SecAcc["🔐 Security Account\n• GuardDuty delegated admin\n• Security Hub delegated admin\n• IAM Access Analyzer"]
    SecurityOU --> LogAcc["🗄️ Log Archive Account\n• Centralized S3 bucket\n• KMS-encrypted logs\n• CloudTrail + Config sink"]

    InfraOU --> NetAcc["🌐 Networking Account\n• Hub VPC\n• Transit Gateway\n• NAT Gateways\n• VPC Endpoints"]
    InfraOU --> SharedAcc["⚙️ Shared Services Account\n• CI/CD\n• Container registries\n• Active Directory"]

    WorkloadsOU --> DevOU["📁 Dev OU"]
    WorkloadsOU --> TestOU["📁 Test OU"]
    WorkloadsOU --> ProdOU["📁 Prod OU"]

    DevOU   --> DevWL["App Workload (Dev)\n• Spoke VPC\n• TGW Attachment"]
    TestOU  --> TestWL["App Workload (Test)\n• Spoke VPC\n• TGW Attachment"]
    ProdOU  --> ProdWL["App Workload (Prod)\n• Spoke VPC\n• TGW Attachment"]

    SandboxOU --> SbxAcc["🧪 Sandbox Accounts"]

    style Root fill:#FF9900,color:#000,font-weight:bold
    style SecurityOU fill:#DD344C,color:#fff
    style InfraOU fill:#1A73E8,color:#fff
    style WorkloadsOU fill:#0F9D58,color:#fff
    style SandboxOU fill:#9E9E9E,color:#fff
    style DevOU fill:#34A853,color:#fff
    style TestOU fill:#FBBC05,color:#000
    style ProdOU fill:#EA4335,color:#fff
```

---

## 2. Network Topology — Hub & Spoke

```mermaid
graph TD
    IGW["🌍 Internet Gateway"]

    subgraph NetAcc["Networking Account — Hub VPC (10.0.0.0/20)"]
        direction TB
        subgraph PubSubnets["Public Subnets"]
            NAT1["NAT GW\nAZ-a"]
            NAT2["NAT GW\nAZ-b"]
        end

        subgraph PrivSubnets["Private Subnets"]
            EP1["VPC Endpoints\n(SSM / S3 / DynamoDB)"]
            EP2["VPC Endpoints\n(EC2Messages / SSMMessages)"]
        end

        subgraph TGWSubnets["Transit Subnets"]
            TGW["🔀 Transit Gateway\n(RAM-shared org-wide)"]
        end

        PubSubnets -->|egress| IGW
        PrivSubnets -->|"0.0.0.0/0"| PubSubnets
        TGWSubnets --- TGW
    end

    subgraph WL_Dev["Workload Dev Account — Spoke VPC"]
        direction TB
        SpokePriv1["Private Subnets"]
        SpokeTGW1["TGW Subnet\n+ Attachment"]
        SpokePriv1 -->|"0.0.0.0/0 → TGW"| SpokeTGW1
    end

    subgraph WL_Prod["Workload Prod Account — Spoke VPC"]
        direction TB
        SpokePriv2["Private Subnets"]
        SpokeTGW2["TGW Subnet\n+ Attachment"]
        SpokePriv2 -->|"0.0.0.0/0 → TGW"| SpokeTGW2
    end

    SpokeTGW1 <-->|TGW Attachment| TGW
    SpokeTGW2 <-->|TGW Attachment| TGW
    TGW <-->|routes| PrivSubnets

    style TGW fill:#FF9900,color:#000,font-weight:bold
    style IGW fill:#1A73E8,color:#fff
    style NetAcc fill:#E3F2FD,color:#000
    style WL_Dev fill:#E8F5E9,color:#000
    style WL_Prod fill:#FCE4EC,color:#000
```

---

## 3. Security & Logging Architecture

```mermaid
graph LR
    subgraph MgmtAcc["Management Account"]
        CloudTrail["☁️ Org CloudTrail\n(multi-region, all accounts)\nKMS encrypted"]
        ConfigRecorder["📋 AWS Config\nOrg Recorder\n+ 7 Managed Rules"]
        AccessAnalyzer["🔍 IAM Access\nAnalyzer\n(ORGANIZATION)"]
        GDAdmin["GuardDuty\nDelegated Admin →"]
        SHAdmin["Security Hub\nDelegated Admin →"]
    end

    subgraph SecAcc["Security Account (Delegated Admin)"]
        GD["🛡️ GuardDuty Detector\n• S3_DATA_EVENTS\n• EKS_AUDIT_LOGS\n• EBS_MALWARE_PROTECTION\nAuto-enable: ALL members"]
        SH["🏛️ Security Hub\n• CIS v1.4.0\n• AWS FSBP v1.0\nAuto-enable: ALL members"]
    end

    subgraph LogAcc["Log Archive Account"]
        S3["🗄️ S3 Log Archive\nKMS-encrypted\nVersioned\nLifecycle: S3-IA → Glacier → Expire"]
        KMS["🔑 KMS Key\n(CloudTrail + Config)"]
        AccessLogBucket["📝 S3 Access\nLogs Bucket"]
    end

    GDAdmin --> GD
    SHAdmin --> SH

    CloudTrail -->|"s3:PutObject\n/cloudtrail/*"| S3
    ConfigRecorder -->|"s3:PutObject\n/aws-config/*"| S3
    S3 -->|access logging| AccessLogBucket
    S3 --- KMS

    subgraph SCPs["Service Control Policies (attached at Root)"]
        SCP1["🚫 DenyRootUserUsage"]
        SCP2["🌏 RestrictRegions"]
        SCP3["🔒 DenyPublicS3"]
        SCP4["🔑 RequireMFA\n(sensitive IAM actions)"]
        SCP5["🚪 DenyLeaveOrganization"]
    end

    style MgmtAcc fill:#FFF8E1,color:#000
    style SecAcc fill:#FCE4EC,color:#000
    style LogAcc fill:#E8EAF6,color:#000
    style SCPs fill:#F3E5F5,color:#000
    style GD fill:#DD344C,color:#fff
    style SH fill:#1A73E8,color:#fff
    style S3 fill:#FF9900,color:#000
```

---

## 4. Identity & Access Architecture

```mermaid
graph TD
    subgraph MgmtAcc["Management Account"]
        SSO["👤 IAM Identity Center\n(SSO)"]
        OIDC["🔗 HCP Terraform\nOIDC Provider"]

        subgraph PermSets["Permission Sets"]
            PS1["AdministratorAccess\n(4h session)"]
            PS2["ReadOnlyAccess\n(8h session)"]
            PS3["NetworkAdministrator"]
            PS4["SecurityAudit"]
            PS5["BillingAccess"]
        end

        SSO --> PermSets
    end

    subgraph TFC["HCP Terraform / Terraform Cloud"]
        WS1["Workspace: plz-root"]
        WS2["Workspace: plz-networking"]
        WS3["Workspace: plz-security"]
        WS4["Workspace: plz-log-archive"]
        WS5["Workspace: plz-identity"]
    end

    subgraph IAMRoles["IAM Roles (per workspace)"]
        R1["myorg-tfc-plz-root\n(AdministratorAccess)"]
        R2["myorg-tfc-plz-networking"]
        R3["myorg-tfc-plz-security"]
    end

    subgraph CrossAcct["Cross-Account Roles (in each member account)"]
        CA1["OrganizationAccountAccessRole\n(used by Terraform providers)"]
        CA2["myorg-cross-account-admin\n(requires MFA)"]
        CA3["myorg-cross-account-readonly"]
    end

    WS1 -->|"OIDC JWT\n(no static keys)"| OIDC
    WS2 -->|"OIDC JWT"| OIDC
    WS3 -->|"OIDC JWT"| OIDC

    OIDC -->|sts:AssumeRoleWithWebIdentity| R1
    OIDC -->|sts:AssumeRoleWithWebIdentity| R2
    OIDC -->|sts:AssumeRoleWithWebIdentity| R3

    R1 -->|sts:AssumeRole| CA1
    R2 -->|sts:AssumeRole| CA1

    subgraph PB["Workload Permission Boundary"]
        PB1["✅ Allow: S3, DynamoDB, SQS,\nSNS, Lambda, Logs, SSM\n❌ Deny: IAM escalation\n❌ Deny: VPC/subnet deletion"]
    end

    CA1 -.->|applied to| PB

    style MgmtAcc fill:#FFF8E1,color:#000
    style TFC fill:#7B42BC,color:#fff
    style IAMRoles fill:#E3F2FD,color:#000
    style CrossAcct fill:#E8F5E9,color:#000
    style PB fill:#F3E5F5,color:#000
    style OIDC fill:#FF9900,color:#000,font-weight:bold
```

---

## 5. Terraform Deployment Order

```mermaid
flowchart LR
    Pre["⚙️ Pre-requisite\nCreate S3 state bucket\n(use_lockfile = true)\nTerraform ≥ 1.10"]

    Pre --> P1

    P1["1️⃣ plz-root\nplatform/plz-root\n─────────────\n• AWS Organization\n• 4 OUs + 3 sub-OUs\n• 5 SCPs on Root\n• 4 platform accounts"]

    P1 --> P2

    P2["2️⃣ plz-log-archive\nplatform/plz-log-archive\n─────────────\n• S3 log archive bucket\n• KMS key + alias\n• Lifecycle policies\n• Bucket policy"]

    P2 --> P3 & P4

    P3["3️⃣ plz-security\nplatform/plz-security\n─────────────\n• GuardDuty (org)\n• Security Hub (org)\n• AWS Config + rules\n• Org CloudTrail\n• IAM Access Analyzer\n⚠️ Needs bucket from P2"]

    P4["4️⃣ plz-networking\nplatform/plz-networking\n─────────────\n• Hub VPC + subnets\n• Transit Gateway\n• NAT Gateways\n• VPC Endpoints\n• RAM TGW share"]

    P3 & P4 --> P5

    P5["5️⃣ plz-identity\nplatform/plz-identity\n─────────────\n• OIDC Provider (TFC)\n• TFC IAM roles\n• SSO Permission Sets\n• Cross-account roles"]

    P5 --> WL

    WL["🔁 workloads/template\n(copy per app × env)\n─────────────\n• Spoke VPC\n• TGW Attachment\n• Private route → TGW\n• Flow Logs\n• Permission Boundary"]

    style Pre fill:#9E9E9E,color:#fff
    style P1 fill:#FF9900,color:#000,font-weight:bold
    style P2 fill:#E8EAF6,color:#000,font-weight:bold
    style P3 fill:#FCE4EC,color:#000,font-weight:bold
    style P4 fill:#E3F2FD,color:#000,font-weight:bold
    style P5 fill:#FFF8E1,color:#000,font-weight:bold
    style WL fill:#E8F5E9,color:#000,font-weight:bold
```
