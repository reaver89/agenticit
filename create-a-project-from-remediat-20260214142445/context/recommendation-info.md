# Task Information

## Overview
- **Customer**: A. Datum Corporation
- **Task ID**: 1287
- **Organization ID**: 9535197a-64b8-4ba6-b441-c31dadbe4676

## Task Details
**Downscale disks**


<br/><b><i>##- Please type your reply above this line -##</i></b><br/>
<h1>Please apply savings strategy below to optimize cost of attached azure resources</h1><p></p>
<h2><a href="https://portal-beta.vbox-cloud.com/organization/9535197a-64b8-4ba6-b441-c31dadbe4676/cost/optimization/details/DUT" target="_blank">Downscale disks</a></h2>
<p><p>There are 4 types of disks: HDD, SSD, premium SSD, and ultra disks. Each type is defined by performance and size constraints. In selecting an appropriate disk size, it is important to consider multiple factors, such as disk queue, IOPS, and throughput.</p><ul><li>Ultra disks<br/>Azure ultra disks are the highest-performing storage option for Azure VMs. You can change the performance parameters of an ultra disk without having to restart your VMs. Ultra disks are suited for data-intensive workloads and are therefore appropriate for SAP HANA, top-tier databases, and transaction-heavy workloads. Ultra disks must be used as data disks and can only be created as empty disks.</li><li>Premium SSDs<br/>Azure premium SSDs deliver high-performance and low-latency disk support for VMs with input/output-intensive workloads. Premium SSDs are suitable for mission-critical production applications, but you can use them only with compatible VM series.</li><li>Standard SSDs<br/>Azure standard SSDs are optimized for workloads that need consistent performance at lower IOPS levels. They&prime;re an especially good choice for varying workloads supported by on-premises HDD solutions. Compared to standard HDDs, standard SSDs deliver better availability, consistency, reliability, and latency. Standard SSDs are suitable for web servers, low IOPS application servers, lightly used enterprise applications, and non-production workloads. Like standard HDDs, standard SSDs are available on all Azure VMs.</li><li>Standard HDDs<br/>Azure standard HDDs deliver reliable, low-cost disk support for VMs running latency-tolerant workloads. With standard storage, your data is stored on HDDs, and performance may vary more widely than with SSD-based disks. When working with VMs, you can use standard HDD disks for dev/test scenarios and less-critical workloads.</li></ul>
<p></p>
<h2>Strategy</h2>
<p><p>Convert premium SSDs to standard SSDs for virtual servers with the following performance metrics:</p><table><thead><tr><th>Name</th><th>Limit</th></tr></thead><tbody><tr><td>OS Disk Queue Depth</td><td>&lt;= 1</td></tr><tr><td>OS per Disk Read Operations/Sec</td><td>&lt;= 500</td></tr><tr><td>OS per Disk Write Operations/Sec</td><td>&lt;= 500</td></tr><tr><td>OS Disk Read MBytes/Sec</td><td>&lt;= 50</td></tr><tr><td>OS Disk Write MBytes/Sec</td><td>&lt;= 50</td></tr></tbody></table><p>Note: To further investigate the applicability of this recommendation, VM Insights must be enabled on the selected set of VMs to collect disk-related Windows performance metrics.</p></p>

        <h2>Estimated Cost Reduction</h2>
        <table>
         <tr>
           <td><strong>Name</strong></td>
           <td><strong>Unhealthy resources</strong></td>
           <td><strong>Current cost, $</strong></td>
           <td><strong>Optimized cost, $</strong></td>
           <td><strong>Saving, $</strong></td>
           <td><strong>Savings/Cost, %</strong></td>
           <td><strong>Savings/Total, %</strong></td>
        </tr>
        <tbody>
        <tr>
            <td>VBox Cloud Subscription</td>
             <td>1</td>
             <td>$2.87</td>
             <td>$1.46</td>
             <td>$1.40</td>
             <td>48.90%</td>
             <td>0.00%</td>
        </tr></tbody>
        <tfoot>
        <tr>
        <td><b>TOTAL:</b></td>
        <td><b>Monthly</b></td>
        <td>
            $2.87
        </td>
        <td>
            $1.46
        </td>
        <td>
            $1.40
        </td>
           <td>
            48.90%
        </td>
           <td>
            0.00%
        </td>
        </tr>
        <tr>
        <td></td>
        <td><b>Annually</b></td>
         <td>
            $34.40
        </td>
        <td>
            $17.58
        </td>
        <td>
            $16.82
        </td>
        </tr>
        </tfoot>
        </table>
<h2>Recommendations</h2>
<ul><li>Enable Azure VM Insights data collection for 2 weeks and analyze performance.</li><li>Change disk type from Premium SSD to Standard SSD.</li></ul>
<p><h2><a href="https://portal-beta.vbox-cloud.com/organization/9535197a-64b8-4ba6-b441-c31dadbe4676/cost/optimization/details/DUT">View Details</a></h2></p>

## Recommendation
**Downscale disks**

Select the appropriate type of disk by analyzing the VM Insights statistics of disk-related Windows performance counters.

## Affected Resources
- **contoso-demo-web-vm_osdisk_1_1acfd0824c5e494591959430df779bdf** (microsoft.compute/disks)
  - Action: Change tier from 'E10 LRS Disk' to 'S10 LRS Disk'
  - ID: `/subscriptions/eca2646b-f770-43f0-8c71-c80e35801b1b/resourcegroups/contoso-demo-rg/providers/microsoft.compute/disks/contoso-demo-web-vm_osdisk_1_1acfd0824c5e494591959430df779bdf`

## Remediation Steps
*No remediation steps provided*

---
*This document was auto-generated from vBox task data.*
