"""
AWS Landing Zone Architecture Diagram
Generates: docs/aws_landing_zone.png
Run: python docs/generate_diagram.py
"""

import matplotlib.pyplot as plt
import matplotlib.patches as mpatches
from matplotlib.patches import FancyBboxPatch, FancyArrowPatch
import matplotlib.patheffects as pe

# ── AWS colour palette ────────────────────────────────────────────────────────
C = {
    "orange":      "#FF9900",
    "dark":        "#232F3E",
    "white":       "#FFFFFF",
    "light_gray":  "#F8F8F8",
    "mid_gray":    "#E8E8E8",
    "security":    "#DD344C",
    "network":     "#8C4FFF",
    "storage":     "#3F8624",
    "mgmt":        "#E7157B",
    "analytics":   "#006AB6",
    "identity":    "#BF0816",
    "compute":     "#FF9900",
    "workload_d":  "#1A73E8",
    "workload_t":  "#FBBC05",
    "workload_p":  "#EA4335",
    "border":      "#CCCCCC",
    "text_dark":   "#1A1A1A",
    "text_light":  "#FFFFFF",
    "arrow":       "#666666",
}

fig, axes = plt.subplots(2, 1, figsize=(22, 28), facecolor=C["light_gray"])
fig.patch.set_facecolor(C["light_gray"])

# ── helper functions ──────────────────────────────────────────────────────────

def box(ax, x, y, w, h, color, alpha=1.0, radius=0.015, zorder=2):
    p = FancyBboxPatch((x, y), w, h,
                       boxstyle=f"round,pad=0,rounding_size={radius}",
                       linewidth=1.5, edgecolor=C["border"],
                       facecolor=color, alpha=alpha, zorder=zorder)
    ax.add_patch(p)
    return p

def header(ax, x, y, w, h, color, text, fontsize=9, text_color=None):
    box(ax, x, y, w, h, color, zorder=3)
    tc = text_color or (C["white"] if color not in (C["white"], C["light_gray"], C["mid_gray"]) else C["text_dark"])
    ax.text(x + w/2, y + h/2, text, ha="center", va="center",
            fontsize=fontsize, fontweight="bold", color=tc, zorder=4,
            wrap=True)

def service_box(ax, x, y, w, h, icon_color, title, subtitle="", fontsize=8):
    box(ax, x, y, w, h, C["white"], zorder=3)
    # coloured left stripe
    box(ax, x, y, 0.008, h, icon_color, zorder=4, radius=0.005)
    ax.text(x + 0.018, y + h * 0.62, title,
            fontsize=fontsize, fontweight="bold", color=C["text_dark"], zorder=5)
    if subtitle:
        ax.text(x + 0.018, y + h * 0.28, subtitle,
                fontsize=max(fontsize - 1.5, 6), color="#555555", zorder=5)

def arrow(ax, x1, y1, x2, y2, color=None, style="->"):
    color = color or C["arrow"]
    ax.annotate("", xy=(x2, y2), xytext=(x1, y1),
                arrowprops=dict(arrowstyle=style, color=color,
                                lw=1.5, connectionstyle="arc3,rad=0.0"),
                zorder=5)

def dashed_arrow(ax, x1, y1, x2, y2, color=None):
    color = color or C["arrow"]
    ax.annotate("", xy=(x2, y2), xytext=(x1, y1),
                arrowprops=dict(arrowstyle="->", color=color,
                                lw=1.3, linestyle="dashed",
                                connectionstyle="arc3,rad=0.0"),
                zorder=5)

def label(ax, x, y, text, fontsize=7.5, color=None, ha="center", va="center", bold=False):
    fw = "bold" if bold else "normal"
    ax.text(x, y, text, ha=ha, va=va, fontsize=fontsize,
            color=color or C["text_dark"], fontweight=fw, zorder=6)

# ═══════════════════════════════════════════════════════════════════════════════
# PANEL 1 — MULTI-ACCOUNT ORG STRUCTURE
# ═══════════════════════════════════════════════════════════════════════════════
ax = axes[0]
ax.set_xlim(0, 1)
ax.set_ylim(0, 1)
ax.set_aspect("equal")
ax.axis("off")
ax.set_facecolor(C["light_gray"])

# ── Title ──
ax.text(0.5, 0.975, "AWS Landing Zone — Multi-Account Structure & Security Stack",
        ha="center", va="top", fontsize=14, fontweight="bold", color=C["dark"])
ax.text(0.5, 0.955, "Terraform-native  ·  AWS Provider ~> 5.0  ·  S3 native locking (Terraform ≥ 1.10)",
        ha="center", va="top", fontsize=9, color="#555555")

# ── Outer Management Account frame ──
box(ax, 0.02, 0.02, 0.96, 0.915, C["light_gray"], zorder=1)
box(ax, 0.02, 0.895, 0.96, 0.038, C["dark"], zorder=2)
ax.text(0.5, 0.914, "  Management Account  (Root)  |  AWS Organizations — All Features Enabled",
        ha="center", va="center", fontsize=10, fontweight="bold", color=C["orange"], zorder=3)

# ── SCPs banner ──
box(ax, 0.04, 0.845, 0.92, 0.038, "#FFF3CD", zorder=2)
ax.text(0.5, 0.864, "Service Control Policies (Root):  (x) DenyRootUser  ·  (r) RestrictRegions  ·  (s) DenyPublicS3  ·   RequireMFA  ·  (l) DenyLeaveOrg",
        ha="center", va="center", fontsize=8, color=C["dark"], zorder=3)

# ── CloudTrail + Config (mgmt) ──
service_box(ax, 0.04, 0.785, 0.21, 0.048, C["mgmt"], "Org CloudTrail", "Multi-region · KMS encrypted", 7.5)
service_box(ax, 0.265, 0.785, 0.21, 0.048, C["mgmt"], "AWS Config", "Org recorder · 7 rules", 7.5)
service_box(ax, 0.49, 0.785, 0.21, 0.048, C["mgmt"], "IAM Access Analyzer", "Scope: ORGANIZATION", 7.5)
service_box(ax, 0.715, 0.785, 0.24, 0.048, C["identity"], "IAM Identity Center (SSO)", "5 permission sets · OIDC for TFC", 7.5)

# ─── SECURITY OU ──────────────────────────────────────────────────────────────
box(ax, 0.04, 0.46, 0.28, 0.305, "#FFEBEE", zorder=2, radius=0.012)
box(ax, 0.04, 0.737, 0.28, 0.028, C["security"], zorder=3, radius=0.005)
ax.text(0.18, 0.751, "  Security OU", ha="center", va="center",
        fontsize=9, fontweight="bold", color=C["white"], zorder=4)

# Security account
box(ax, 0.055, 0.59, 0.245, 0.132, C["white"], zorder=3, radius=0.008)
box(ax, 0.055, 0.7, 0.245, 0.022, C["security"], zorder=4, radius=0.005)
ax.text(0.178, 0.711, "Security Account", ha="center", va="center",
        fontsize=8, fontweight="bold", color=C["white"], zorder=5)
service_box(ax, 0.063, 0.648, 0.108, 0.040, C["security"], "GuardDuty", "Org delegated admin", 7)
service_box(ax, 0.178, 0.648, 0.108, 0.040, C["security"], "Security Hub", "CIS v1.4 · FSBP v1.0", 7)
service_box(ax, 0.063, 0.600, 0.108, 0.040, "#5A6C84", "Macie", "Data classification", 7)
service_box(ax, 0.178, 0.600, 0.108, 0.040, C["analytics"], "Security Lake", "OCSF · Athena queries", 7)

# Log archive account
box(ax, 0.055, 0.47, 0.245, 0.107, C["white"], zorder=3, radius=0.008)
box(ax, 0.055, 0.555, 0.245, 0.022, "#5C6BC0", zorder=4, radius=0.005)
ax.text(0.178, 0.566, "Log Archive Account", ha="center", va="center",
        fontsize=8, fontweight="bold", color=C["white"], zorder=5)
service_box(ax, 0.063, 0.513, 0.108, 0.035, C["storage"], "S3 Log Archive", "KMS-enc · Versioned", 7)
service_box(ax, 0.178, 0.513, 0.108, 0.035, C["orange"], "KMS Key", "CloudTrail + Config", 7)
service_box(ax, 0.063, 0.472, 0.227, 0.033, "#78909C", "Lifecycle: STANDARD→IA(30d)→GLACIER(90d)→Expire(365d)", "", 6.5)

# ─── INFRASTRUCTURE OU ────────────────────────────────────────────────────────
box(ax, 0.34, 0.46, 0.3, 0.305, "#E8EAF6", zorder=2, radius=0.012)
box(ax, 0.34, 0.737, 0.3, 0.028, C["network"], zorder=3, radius=0.005)
ax.text(0.49, 0.751, "  Infrastructure OU", ha="center", va="center",
        fontsize=9, fontweight="bold", color=C["white"], zorder=4)

# Networking account (hub)
box(ax, 0.355, 0.55, 0.27, 0.174, C["white"], zorder=3, radius=0.008)
box(ax, 0.355, 0.702, 0.27, 0.022, C["network"], zorder=4, radius=0.005)
ax.text(0.49, 0.713, "Networking Account — Hub VPC (10.0.0.0/20)", ha="center", va="center",
        fontsize=7.5, fontweight="bold", color=C["white"], zorder=5)
service_box(ax, 0.363, 0.658, 0.12, 0.036, C["network"], "Transit Gateway", "RAM org-wide share", 7)
service_box(ax, 0.493, 0.658, 0.122, 0.036, C["network"], "Internet Gateway", "Public egress", 7)
service_box(ax, 0.363, 0.615, 0.12, 0.036, "#FF7043", "NAT Gateways", "1 per AZ · Elastic IPs", 7)
service_box(ax, 0.493, 0.615, 0.122, 0.036, C["network"], "VPC Endpoints", "SSM · S3 · DynamoDB", 7)
service_box(ax, 0.363, 0.558, 0.252, 0.050, "#546E7A", "Network Firewall",
            "Stateful rules · DENYLIST/ALLOWLIST · Suricata · FLOW+ALERT logs", 7)

# Shared services account
box(ax, 0.355, 0.47, 0.27, 0.065, C["white"], zorder=3, radius=0.008)
box(ax, 0.355, 0.513, 0.27, 0.022, "#546E7A", zorder=4, radius=0.005)
ax.text(0.49, 0.524, "Shared Services Account", ha="center", va="center",
        fontsize=7.5, fontweight="bold", color=C["white"], zorder=5)
service_box(ax, 0.363, 0.472, 0.08, 0.034, C["orange"], "CI/CD", "CodePipeline", 7)
service_box(ax, 0.451, 0.472, 0.08, 0.034, C["orange"], "ECR", "Container registry", 7)
service_box(ax, 0.539, 0.472, 0.076, 0.034, "#546E7A", "AD / DNS", "Route53 Resolver", 7)

# ─── WORKLOADS OU ────────────────────────────────────────────────────────────
box(ax, 0.66, 0.46, 0.30, 0.305, "#E8F5E9", zorder=2, radius=0.012)
box(ax, 0.66, 0.737, 0.30, 0.028, "#2E7D32", zorder=3, radius=0.005)
ax.text(0.81, 0.751, "  Workloads OU", ha="center", va="center",
        fontsize=9, fontweight="bold", color=C["white"], zorder=4)

workloads = [
    (0.672, C["workload_d"], "Dev OU",  "10.10.x.0/24"),
    (0.754, C["workload_t"], "Test OU", "10.20.x.0/24"),
    (0.836, C["workload_p"], "Prod OU", "10.30.x.0/24"),
]
for wx, wc, wname, wcidr in workloads:
    box(ax, wx, 0.470, 0.075, 0.255, C["white"], zorder=3, radius=0.008)
    box(ax, wx, 0.703, 0.075, 0.022, wc, zorder=4, radius=0.005)
    ax.text(wx + 0.038, 0.714, wname, ha="center", va="center",
            fontsize=7.5, fontweight="bold", color=C["white"], zorder=5)
    # Spoke VPC box
    box(ax, wx + 0.004, 0.598, 0.067, 0.096, "#F5F5F5", zorder=4, radius=0.005)
    ax.text(wx + 0.038, 0.673, "Spoke VPC", ha="center", va="center",
            fontsize=7, fontweight="bold", color=C["dark"], zorder=5)
    ax.text(wx + 0.038, 0.655, wcidr, ha="center", va="center",
            fontsize=6.5, color="#555", zorder=5)
    ax.text(wx + 0.038, 0.633, "Private subnets", ha="center", va="center",
            fontsize=6.5, color="#555", zorder=5)
    ax.text(wx + 0.038, 0.614, "No IGW", ha="center", va="center",
            fontsize=6.5, color=C["security"], zorder=5)
    # TGW attachment
    box(ax, wx + 0.004, 0.557, 0.067, 0.033, "#E3F2FD", zorder=4, radius=0.005)
    ax.text(wx + 0.038, 0.574, "TGW Attach", ha="center", va="center",
            fontsize=6.5, color=C["network"], fontweight="bold", zorder=5)
    ax.text(wx + 0.038, 0.563, "0.0.0.0/0→TGW", ha="center", va="center",
            fontsize=6, color="#666", zorder=5)
    # Perm boundary
    box(ax, wx + 0.004, 0.476, 0.067, 0.073, "#FFF8E1", zorder=4, radius=0.005)
    ax.text(wx + 0.038, 0.540, "Permission", ha="center", va="center",
            fontsize=6.5, color="#F57F17", fontweight="bold", zorder=5)
    ax.text(wx + 0.038, 0.530, "Boundary", ha="center", va="center",
            fontsize=6.5, color="#F57F17", fontweight="bold", zorder=5)
    ax.text(wx + 0.038, 0.516, "[+] S3/DDB/Lambda", ha="center", va="center",
            fontsize=6, color="#4CAF50", zorder=5)
    ax.text(wx + 0.038, 0.506, "[-] IAM escalation", ha="center", va="center",
            fontsize=6, color=C["security"], zorder=5)
    ax.text(wx + 0.038, 0.495, "[-] VPC deletion", ha="center", va="center",
            fontsize=6, color=C["security"], zorder=5)
    ax.text(wx + 0.038, 0.482, "VPC Flow Logs", ha="center", va="center",
            fontsize=6, color="#777", zorder=5)

# ─── Sandbox OU ──────────────────────────────────────────────────────────────
box(ax, 0.66, 0.36, 0.30, 0.09, "#F5F5F5", zorder=2, radius=0.012)
box(ax, 0.66, 0.428, 0.30, 0.022, "#9E9E9E", zorder=3, radius=0.005)
ax.text(0.81, 0.439, "  Sandbox OU", ha="center", va="center",
        fontsize=8.5, fontweight="bold", color=C["white"], zorder=4)
ax.text(0.81, 0.400, "Experimental accounts — relaxed guardrails", ha="center", va="center",
        fontsize=8, color="#777", zorder=4)
ax.text(0.81, 0.380, "Budget alerts · Auto-cleanup Lambda", ha="center", va="center",
        fontsize=7.5, color="#999", zorder=4)

# ─── Arrows ──────────────────────────────────────────────────────────────────
# CloudTrail → Log Archive
arrow(ax, 0.145, 0.785, 0.145, 0.578)
label(ax, 0.11, 0.685, "s3:PutObject\n/cloudtrail/*", 6.5, "#555")

# Config → Log Archive
arrow(ax, 0.37, 0.785, 0.23, 0.578)
label(ax, 0.315, 0.70, "s3:PutObject\n/aws-config/*", 6.5, "#555")

# GuardDuty Delegated Admin arrow
dashed_arrow(ax, 0.18, 0.785, 0.178, 0.690)
label(ax, 0.225, 0.74, "delegated\nadmin", 6.5, "#999")

# TGW ← → Spoke VPCs
for wx in [0.672, 0.754, 0.836]:
    arrow(ax, 0.49, 0.575, wx + 0.038, 0.592, C["network"])

label(ax, 0.585, 0.575, "TGW\nAttachments", 7, C["network"], bold=True)

# ─── Legend ──────────────────────────────────────────────────────────────────
legend_items = [
    (C["security"],  "Security services"),
    (C["network"],   "Networking services"),
    (C["storage"],   "Storage / Logging"),
    (C["orange"],    "AWS Core / Compute"),
    (C["identity"],  "Identity & Access"),
    (C["analytics"], "Analytics / SIEM"),
    (C["mgmt"],      "Management & Governance"),
]
lx, ly = 0.04, 0.335
ax.text(lx, ly + 0.015, "Legend:", fontsize=8, fontweight="bold", color=C["dark"])
for i, (lc, lt) in enumerate(legend_items):
    col = i % 4
    row = i // 4
    bx = lx + col * 0.23
    by = ly - row * 0.022
    p = FancyBboxPatch((bx, by - 0.008), 0.015, 0.013,
                       boxstyle="round,pad=0,rounding_size=0.003",
                       facecolor=lc, edgecolor=C["border"], linewidth=0.8, zorder=3)
    ax.add_patch(p)
    ax.text(bx + 0.022, by - 0.001, lt, fontsize=7.5, va="center", color=C["text_dark"])


# ═══════════════════════════════════════════════════════════════════════════════
# PANEL 2 — NETWORK TOPOLOGY + DEPLOYMENT ORDER
# ═══════════════════════════════════════════════════════════════════════════════
ax2 = axes[1]
ax2.set_xlim(0, 1)
ax2.set_ylim(0, 1)
ax2.set_aspect("equal")
ax2.axis("off")
ax2.set_facecolor(C["light_gray"])

ax2.text(0.5, 0.975, "AWS Landing Zone — Network Topology & Deployment Order",
         ha="center", va="top", fontsize=14, fontweight="bold", color=C["dark"])

# ─── LEFT HALF: Network Topology ─────────────────────────────────────────────
ax2.text(0.25, 0.945, "Hub & Spoke Network Topology",
         ha="center", va="top", fontsize=11, fontweight="bold", color=C["network"])

# Internet
box(ax2, 0.05, 0.875, 0.38, 0.048, C["dark"], zorder=2, radius=0.010)
ax2.text(0.24, 0.899, "  Internet", ha="center", va="center",
         fontsize=9, fontweight="bold", color=C["orange"], zorder=3)

arrow(ax2, 0.24, 0.875, 0.24, 0.848)

# Hub VPC
box(ax2, 0.05, 0.62, 0.38, 0.218, "#E8EAF6", zorder=2, radius=0.012)
box(ax2, 0.05, 0.816, 0.38, 0.028, C["network"], zorder=3)
ax2.text(0.24, 0.830, "Networking Account — Hub VPC (10.0.0.0/20)", ha="center", va="center",
         fontsize=8.5, fontweight="bold", color=C["white"], zorder=4)

# Public subnets
box(ax2, 0.065, 0.757, 0.165, 0.048, "#C5CAE9", zorder=3, radius=0.008)
ax2.text(0.148, 0.781, "Public Subnets", ha="center", va="center",
         fontsize=8, fontweight="bold", color=C["dark"], zorder=4)
ax2.text(0.148, 0.768, "NAT GW AZ-a  ·  NAT GW AZ-b", ha="center", va="center",
         fontsize=7, color="#555", zorder=4)

# Firewall
box(ax2, 0.245, 0.757, 0.165, 0.048, "#B71C1C", zorder=3, radius=0.008, alpha=0.85)
ax2.text(0.328, 0.781, "Network Firewall", ha="center", va="center",
         fontsize=8, fontweight="bold", color=C["white"], zorder=4)
ax2.text(0.328, 0.768, "Stateful · Suricata rules", ha="center", va="center",
         fontsize=7, color="#FFCDD2", zorder=4)

# Private subnets
box(ax2, 0.065, 0.697, 0.165, 0.048, "#C5CAE9", zorder=3, radius=0.008)
ax2.text(0.148, 0.721, "Private Subnets", ha="center", va="center",
         fontsize=8, fontweight="bold", color=C["dark"], zorder=4)
ax2.text(0.148, 0.708, "SSM · S3 · DDB endpoints", ha="center", va="center",
         fontsize=7, color="#555", zorder=4)

# TGW
box(ax2, 0.245, 0.697, 0.165, 0.048, C["network"], zorder=3, radius=0.008)
ax2.text(0.328, 0.721, "Transit Gateway", ha="center", va="center",
         fontsize=8, fontweight="bold", color=C["white"], zorder=4)
ax2.text(0.328, 0.708, "RAM shared · Org-wide", ha="center", va="center",
         fontsize=7, color="#E8EAF6", zorder=4)

# Transit subnets
box(ax2, 0.065, 0.632, 0.345, 0.052, "#9FA8DA", zorder=3, radius=0.008)
ax2.text(0.238, 0.658, "Transit Subnets (TGW ENIs)  ·  AZ-a  ·  AZ-b",
         ha="center", va="center", fontsize=7.5, color=C["white"], fontweight="bold", zorder=4)

# Hub internal arrows
arrow(ax2, 0.148, 0.757, 0.148, 0.745)
arrow(ax2, 0.148, 0.697, 0.148, 0.684)
arrow(ax2, 0.328, 0.757, 0.328, 0.745)
arrow(ax2, 0.328, 0.697, 0.328, 0.684)

# Spoke VPCs
spoke_configs = [
    (0.055, C["workload_d"], "Dev Spoke\n10.10.0.0/24"),
    (0.158, C["workload_t"], "Test Spoke\n10.20.0.0/24"),
    (0.261, C["workload_p"], "Prod Spoke\n10.30.0.0/24"),
    (0.352, "#78909C",       "Future\nSpokes"),
]
for sx, sc, sname in spoke_configs:
    box(ax2, sx, 0.480, 0.085, 0.132, C["white"], zorder=3, radius=0.008)
    box(ax2, sx, 0.590, 0.085, 0.022, sc, zorder=4, radius=0.005)
    for line_i, line in enumerate(sname.split("\n")):
        ax2.text(sx + 0.043, 0.598 + line_i * 0.01 * (-1),
                 line, ha="center", va="center",
                 fontsize=7, fontweight="bold", color=C["white"], zorder=5)
    ax2.text(sx + 0.043, 0.564, "Private subnets", ha="center", va="center",
             fontsize=6.5, color="#555", zorder=5)
    ax2.text(sx + 0.043, 0.552, "No IGW", ha="center", va="center",
             fontsize=6.5, color=C["security"], zorder=5)
    ax2.text(sx + 0.043, 0.538, "VPC Flow Logs", ha="center", va="center",
             fontsize=6.5, color="#777", zorder=5)
    box(ax2, sx + 0.008, 0.485, 0.067, 0.030, "#E3F2FD", zorder=4, radius=0.005)
    ax2.text(sx + 0.043, 0.500, "0.0.0.0/0→TGW", ha="center", va="center",
             fontsize=6.5, color=C["network"], zorder=5)

# TGW ↔ Spoke arrows
for sx in [0.055, 0.158, 0.261, 0.352]:
    arrow(ax2, sx + 0.043, 0.612, sx + 0.043, 0.632, C["network"])
    arrow(ax2, sx + 0.043, 0.632, sx + 0.043, 0.612, C["network"])

ax2.text(0.24, 0.462, "All egress routes 0.0.0.0/0 → TGW → Hub NAT  (no direct internet from workloads)",
         ha="center", fontsize=8, color="#555", style="italic")

# ─── RIGHT HALF: Deployment Order ────────────────────────────────────────────
ax2.text(0.75, 0.945, "Terraform Deployment Order",
         ha="center", va="top", fontsize=11, fontweight="bold", color=C["dark"])

steps = [
    (0.51, 0.865, C["mid_gray"],  "#333",       "PRE",  "Create S3 State Bucket",
     "use_lockfile=true · no DynamoDB · Terraform ≥ 1.10"),
    (0.51, 0.760, C["orange"],    C["dark"],     " 1 ",  "plz-root",
     "Org · OUs · SCPs · 4 platform accounts"),
    (0.51, 0.655, "#E8EAF6",      C["dark"],     " 2 ",  "plz-log-archive",
     "S3 log archive · KMS key · Lifecycle policy"),
    (0.51, 0.550, "#FFEBEE",      C["dark"],     " 3 ",  "plz-security",
     "GuardDuty · Security Hub · Config · CloudTrail"),
    (0.755, 0.550, "#E3F2FD",     C["dark"],     " 4 ",  "plz-networking",
     "Hub VPC · TGW · NAT GWs · VPC Endpoints · RAM"),
    (0.51, 0.445, "#FFF8E1",      C["dark"],     " 5 ",  "plz-identity",
     "OIDC · TFC roles · SSO permission sets"),
    (0.51, 0.340, "#E8F5E9",      C["dark"],     "WL",   "workloads/template",
     "Copy per app × env · Spoke VPC · TGW attach"),
]

for (bx, by, bc, tc, num, title, desc) in steps:
    box(ax2, bx, by, 0.225, 0.083, bc, zorder=3, radius=0.008)
    # Step number badge
    box(ax2, bx + 0.008, by + 0.040, 0.032, 0.032, C["dark"], zorder=4, radius=0.005)
    ax2.text(bx + 0.024, by + 0.056, num, ha="center", va="center",
             fontsize=8.5, fontweight="bold", color=C["orange"], zorder=5)
    ax2.text(bx + 0.050, by + 0.058, title, ha="left", va="center",
             fontsize=9, fontweight="bold", color=tc, zorder=5)
    ax2.text(bx + 0.050, by + 0.038, desc, ha="left", va="center",
             fontsize=7.5, color="#555", zorder=5)

# Deployment arrows
arrow(ax2, 0.623, 0.848, 0.623, 0.838)   # PRE→1
arrow(ax2, 0.623, 0.760, 0.623, 0.738)   # 1→2
arrow(ax2, 0.623, 0.655, 0.623, 0.633)   # 2→3
arrow(ax2, 0.623, 0.550, 0.623, 0.528)   # 3→5 (left path)
# 2→4 (right path)
ax2.annotate("", xy=(0.868, 0.633), xytext=(0.703, 0.655),
             arrowprops=dict(arrowstyle="->", color=C["arrow"], lw=1.5,
                             connectionstyle="arc3,rad=0.0"), zorder=5)
ax2.annotate("", xy=(0.623, 0.528), xytext=(0.868, 0.550),
             arrowprops=dict(arrowstyle="->", color=C["arrow"], lw=1.5,
                             connectionstyle="arc3,rad=-0.3"), zorder=5)
arrow(ax2, 0.623, 0.445, 0.623, 0.423)   # 5→WL

ax2.text(0.623, 0.543, "parallel", ha="center", fontsize=7, color="#999", style="italic")
ax2.text(0.623, 0.537, "deploy", ha="center", fontsize=7, color="#999", style="italic")

# Provider pattern note
box(ax2, 0.51, 0.255, 0.47, 0.070, "#FFF3CD", zorder=3, radius=0.008)
ax2.text(0.745, 0.307, "(!)  plz-security uses TWO providers",
         ha="center", va="center", fontsize=8.5, fontweight="bold", color=C["dark"], zorder=4)
ax2.text(0.745, 0.290, "Management account (default)  +  Security account (aws.security alias)",
         ha="center", va="center", fontsize=8, color="#555", zorder=4)
ax2.text(0.745, 0.272, "configuration_aliases = [aws.security]  in module  ·  assume_role in provider block",
         ha="center", va="center", fontsize=7.5, color="#777", style="italic", zorder=4)

# AFT vending note
box(ax2, 0.51, 0.175, 0.47, 0.065, "#E8F5E9", zorder=3, radius=0.008)
ax2.text(0.745, 0.225, "(->)  Account Vending (AFT upgrade path)",
         ha="center", va="center", fontsize=8.5, fontweight="bold", color="#2E7D32", zorder=4)
ax2.text(0.745, 0.207, "workloads/template → aft-account-customizations",
         ha="center", va="center", fontsize=8, color="#555", zorder=4)
ax2.text(0.745, 0.190, "PR to aft-account-request → 30–60 min automated provisioning",
         ha="center", va="center", fontsize=7.5, color="#777", zorder=4)

# ── final watermark ──────────────────────────────────────────────────────────
fig.text(0.5, 0.005, "AWS Landing Zone  ·  Terraform ≥ 1.10  ·  AWS Provider ~> 5.0  ·  S3 native state locking",
         ha="center", fontsize=8, color="#AAAAAA")

plt.tight_layout(pad=1.5)
out = r"C:\Projects_IAC\AWS\terraform\docs\aws_landing_zone.png"
plt.savefig(out, dpi=150, bbox_inches="tight", facecolor=C["light_gray"])
print(f"Saved: {out}")
plt.close()
