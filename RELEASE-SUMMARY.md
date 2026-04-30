# Submariner Release Process - Quick Reference

## 📋 Overview

**What:** Publish 9 container images + 6 FBC catalogs to Red Hat registries  
**How:** 20-step workflow through Konflux CI/CD platform  
**When:** Y-stream (0.21→0.22) or Z-stream (0.21.1→0.21.2)  
**Time:** 1-3 weeks total (20-40 hours active work + QE approval wait)

---

## ⏱️ Timeline at a Glance

| Phase | Steps | Active Time | Wait Time | Y-stream | Z-stream |
|-------|-------|-------------|-----------|----------|----------|
| **Setup** | 1-3b | 4-8 hours | - | ✅ Required | ⏭️ Skip |
| **Build Prep** | 4-7 | 7-33 hours | 2 hours (pipelines) | ✅ | ✅ |
| **Stage** | 8-14 | 4-6 hours | 1-2 hours (pipelines) + **3-14 days (QE)** | ✅ | ✅ |
| **Production** | 15-20 | 2-3 hours | 1 hour (pipelines) | ✅ | ✅ |

**Total:** 17-50 hours (Y-stream) or 13-42 hours (Z-stream) + QE approval time

---

## 🚦 Critical Path

```
Setup (Y-stream) → EC Violations → CVE Fixes → Upstream Release → 
Bundle Update → Stage Release → FBC Stage → QE APPROVAL → Production
```

**Longest waits:**
1. QE approval: 3-14 days ⚠️
2. CVE fixes: 4-24 hours (iterative)
3. Pipeline executions: ~2-4 hours total

---

## 📊 Effort Distribution

### Y-stream (New Minor Version: 0.21 → 0.22)

```
Setup (20%)          Build Prep (45%)      Stage (20%)         Prod (15%)
├─ Branches          ├─ EC Violations      ├─ Create YAML      ├─ Create Prod YAML
├─ Konflux Config    ├─ CVE Scanning ⏳    ├─ Release Notes    ├─ Apply Release
├─ Tekton PRs        ├─ Version Labels     ├─ Apply Release    ├─ FBC Prod
└─ Bundle Setup      └─ Bundle SHAs        └─ FBC Stage        └─ Notify QE
4-8 hrs              7-33 hrs ⚠️           4-6 hrs + QE ⏸️     2-3 hrs
```

### Z-stream (Patch Release: 0.21.1 → 0.21.2)

```
                     Build Prep (55%)      Stage (25%)         Prod (20%)
                     ├─ EC Violations      ├─ Create YAML      ├─ Create Prod YAML
                     ├─ CVE Scanning ⏳    ├─ Release Notes    ├─ Apply Release
                     ├─ Version Labels     ├─ Apply Release    ├─ FBC Prod
                     └─ Bundle SHAs        └─ FBC Stage        └─ Notify QE
                     7-33 hrs ⚠️           4-6 hrs + QE ⏸️     2-3 hrs
```

**Legend:** ⏳ Variable time | ⏸️ External dependency | ⚠️ High risk area

---

## 🎯 Key Milestones

| Milestone | Definition | Verification |
|-----------|------------|--------------|
| **Setup Complete** | ReleasePlans deployed, builds passing | `oc get releaseplans -n submariner-tenant` |
| **Build Ready** | EC passed, CVEs triaged, bundle updated | Latest snapshot has all tests passed |
| **Stage Complete** | Component + FBC in stage registries | 6 FBC releases succeeded |
| **QE Approved** | Stage testing passed, ready for prod | Jira ticket approved |
| **Prod Complete** | Component + FBC in production | Visible in OperatorHub |

---

## ⚡ Automation Level

| Category | Steps | Time Saved | Automation Status |
|----------|-------|------------|-------------------|
| **Fully Automated** | 1, 6, 10, 13, 16, 18 | ~2 hours | ✅ Complete |
| **Script-Assisted** | 7, 9, 12 | ~4 hours | ⚙️ Tools available |
| **Manual** | 2, 3, 3b, 4, 5, 5b | ~30 hours | ⏳ Human judgment required |

**Automation opportunities:** Steps 2, 3, 9 (in progress)

---

## 🚨 Common Blockers

### Phase 2: Build Prep (Most Common)
1. **CVE Fixes** (4-24 hours)
   - Critical CVEs in Go stdlib require upstream updates
   - Iterative fix→rebuild→rescan cycle
   - **Mitigation:** Start CVE scanning early, parallel track fixes

2. **EC Violations** (2-8 hours)
   - Policy changes require code/config updates
   - Hermetic build issues (RPM lockfiles)
   - **Mitigation:** Monitor EC policy repo, validate early

### Phase 3: Stage (Longest Wait)
3. **QE Approval** (3-14 days)
   - External dependency, unpredictable timeline
   - Issues found require fix→rebuild→retest cycle
   - **Mitigation:** Clear release notes, comprehensive pre-QE testing

### Phase 4: Production (Rare)
4. **Pipeline Failures** (retry adds 1 hour)
   - Intermittent infrastructure issues
   - Multi-arch build timeouts
   - **Mitigation:** Automatic retries, monitoring

---

## 📦 Deliverables

### Stage Release (Step 14)
- ✅ Bundle: `registry.stage.redhat.io/rhacm2/submariner-operator-bundle:v0.X.Y`
- ✅ 6 FBC catalogs in stage indices (OCP 4.16-4.21)
- ✅ Release notes with CVEs and issues
- ✅ Jira ticket for QE with catalog URLs

### Production Release (Step 19)
- ✅ Bundle: `registry.redhat.io/rhacm2/submariner-operator-bundle:v0.X.Y`
- ✅ 6 FBC catalogs in production indices
- ✅ Visible in OperatorHub across supported OCP versions
- ✅ QE notified of production availability

---

## 👥 Roles & Responsibilities

| Role | Responsibilities | Time Commitment |
|------|------------------|-----------------|
| **Release Manager** | Orchestrate process, triage decisions | 50-80% (active phases) |
| **Developer** | CVE fixes, EC violation fixes | As needed (on-call) |
| **QE** | Stage testing, approval decision | 3-14 days (external) |
| **Automation Engineer** | Script improvements, debugging | 10-20% (support) |

---

## 🔗 Quick Links

- **Status Check:** `./scripts/release-status.sh 0.X.Y`
- **Detailed Workflows:** `.agents/workflows/` directory
- **Skills/Automation:** `/skills/` directory
- **Full Overview:** `RELEASE-PROCESS-OVERVIEW.md`
- **Learn Tool:** `/learn-release [overview|step N|all]`

---

## 📈 Success Metrics

| Metric | Target | Current |
|--------|--------|---------|
| **Time to Stage** | <2 weeks (Y-stream) | 1.5-3 weeks |
| **Time to Stage** | <1 week (Z-stream) | 1-2 weeks |
| **CVE-free Releases** | >80% | ~70% |
| **QE First-pass Success** | >90% | ~85% |
| **Pipeline Retry Rate** | <10% | ~5% |

---

## 💡 Quick Tips for Teams

1. **Start Early:** Begin CVE scanning as soon as possible (Step 5)
2. **Parallelize:** Work on multiple repos simultaneously during Step 3
3. **Test Before QE:** Validate stage release thoroughly before Step 14
4. **Monitor Pipelines:** Check builds during wait times to catch failures early
5. **Document Issues:** Track blockers for process improvement

---

**Last Updated:** 2026-04-08  
**Process Version:** Konflux-based (2024+)  
**For:** ACM/Submariner Engineering Teams
