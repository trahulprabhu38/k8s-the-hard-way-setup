
# 1. Private IP Ranges (What addresses are allowed)

These are the **only address spaces AWS allows for private VPC networking**.

| Range                         | CIDR           |
| ----------------------------- | -------------- |
| 10.0.0.0 – 10.255.255.255     | 10.0.0.0/8     |
| 172.16.0.0 – 172.31.255.255   | 172.16.0.0/12  |
| 192.168.0.0 – 192.168.255.255 | 192.168.0.0/16 |

These ranges come from **RFC1918 private networking standards**.


**classful networking**.
Example:

| Class   | Default |
| ------- | ------- |
| Class A | /8      |
| Class B | /16     |
| Class C | /24     |

But **modern networking no longer uses classful networks**. Everything uses **CIDR**.
So `/24` is **not a required private range**. It’s just a **subnet size**.

---

# 2. AWS VPC Size Limits

When you create a VPC, AWS restricts **how big or small the VPC network can be**.

| Limit        | Meaning |
| ------------ | ------- |
| Largest VPC  | /16     |
| Smallest VPC | /28     |

So AWS allows VPC sizes **between `/16` and `/28`**.

Examples of valid VPCs:

```
10.0.0.0/16
10.0.0.0/20
10.0.0.0/24
10.0.0.0/28
```

But not:

```
10.0.0.0/8
```

because `/8` is **too large for AWS VPC**.

---

# 3. Putting Both Rules Together

To create a VPC, two conditions must be satisfied:

### Rule 1

The address must come from a **private range**

Example:

```
10.x.x.x
172.16–31.x.x
192.168.x.x
```

### Rule 2

The **CIDR size must be between `/16` and `/28`**

---

# 4. Valid Examples

These are valid VPC CIDRs:

```
10.0.0.0/16
10.10.0.0/16
172.20.0.0/20
192.168.0.0/24
```

---

# 5. Invalid Examples

Invalid because too large:

```
10.0.0.0/8
```

Invalid because public IP:

```
8.8.8.0/24
```

---

# 6. Why AWS Uses /16 as the Maximum

A `/8` network contains:

```
16,777,216 IP addresses
```

That is **too large for AWS networking architecture**, so AWS caps it at `/16`.

A `/16` network contains:

```
65,536 IP addresses
```

Which is plenty for most VPCs.

---

Now that the **VPC CIDR concept is clear**, let’s move to the **CIDR rules for subnets and other AWS resources**, and then explain **why AWS reserves 5 IPs in every subnet**.

---


# 7. How Many IPs Each Subnet Gets

CIDR determines how many total IP addresses exist.

| Subnet | Total IPs |
| ------ | --------- |
| /24    | 256       |
| /25    | 128       |
| /26    | 64        |
| /27    | 32        |
| /28    | 16        |

Formula:

```
2^(32 - prefix)
```

Example:

```
/24 → 2^(32-24) = 256
```

---

# 8. Why AWS Reserves 5 IP Addresses

In **every AWS subnet**, the **first 4 and the last 1 IP addresses cannot be used**.

Example subnet:

```
10.0.1.0/24
```

Total IPs:

```
256
```

AWS reserves:

| IP         | Purpose           |
| ---------- | ----------------- |
| 10.0.1.0   | Network address   |
| 10.0.1.1   | VPC router        |
| 10.0.1.2   | DNS server        |
| 10.0.1.3   | Reserved for AWS  |
| 10.0.1.255 | Broadcast address |

So usable IPs become:

```
256 - 5 = 251
```

---

# 9. Example With /28 Subnet

Subnet:

```
10.0.1.0/28
```

Total IPs:

```
16
```

Addresses:

```
10.0.1.0
10.0.1.1
10.0.1.2
10.0.1.3
10.0.1.4
...
10.0.1.15
```

AWS reserves:

```
10.0.1.0
10.0.1.1
10.0.1.2
10.0.1.3
10.0.1.15
```

Usable:

```
16 - 5 = 11
```

---

# 10. Quick Memory Rule

Total IPs:

```
2^(32 - CIDR)
```

Usable IPs in AWS:

```
2^(32 - CIDR) - 5
```

---

If you want, next I can explain **subnetting visually with binary**, which is what actually makes `/16`, `/24`, `/28` instantly understandable.

---


# DNS resolver


AWS managed --> 169.254.169.253
vpc specific is the 2nd ip , eg: 10.0.0.0/16 --> dns is in 10.0.0.2


# few cmds:
-  cat /etc/resolv.conf
- nslookup google.com