# Flowdometer Utility Scripts

This directory contains utility scripts for Flowdometer development and testing. **These scripts are NOT part of the package** and will not be deployed to subscriber orgs.

---

## 📁 Directory Structure

```
scripts/
├── apex/              # Anonymous Apex scripts
│   ├── seedTestData.apex       # Create sample Flow/Step data
│   ├── cleanupTestData.apex    # Delete test data
│   ├── auditAllReports.apex    # Test all reports for errors
│   └── hello.apex              # Example script
└── soql/              # SOQL queries
    └── account.soql            # Example query
```

---

## 🔧 Apex Scripts

### 1. **seedTestData.apex** - Create Test Data

**Purpose:** Creates sample Flow and Step records for testing reports and dashboards.

**What it creates:**
- 5 Opportunity records (to track)
- 2 Flow Goal records (SLA targets)
- 7 Flow Tracker records (tracking the Opportunities)
- 20 Step Goal records (stage-level SLAs)
- 30+ Step Tracker records (progress through stages)

**How to run:**
```bash
# Option A: Using Salesforce CLI
sf apex run --file scripts/apex/seedTestData.apex --target-org PBODevHub

# Option B: In Salesforce UI
# 1. Open Developer Console
# 2. Debug → Open Execute Anonymous Window
# 3. Copy/paste contents of seedTestData.apex
# 4. Click "Execute"
# 5. Check debug log for results
```

**Expected Output:**
```
=== Test Data Seed Complete ===
Summary:
  - 5 Opportunities
  - 2 Flow Goals
  - 7 Flow Trackers
  - 20 Step Goals
  - 35 Step Trackers
```

---

### 2. **cleanupTestData.apex** - Delete Test Data

**Purpose:** Removes ALL test data created by `seedTestData.apex`.

**How to run:**
```bash
sf apex run --file scripts/apex/cleanupTestData.apex --target-org PBODevHub
```

**WARNING:** This deletes all test data! Only run this when you're done testing.

---

### 3. **auditAllReports.apex** - Audit Reports

**Purpose:** Tests all Flowdometer reports to ensure they run without errors.

**What it checks:**
- ✅ Reports can be described (no field errors)
- ✅ Reports can be executed (no runtime errors)
- ⚠️ Reports using deprecated fields (will break after Phase 6)
- 💡 Unreferenced reports (not used in dashboards)

**How to run:**
```bash
sf apex run --file scripts/apex/auditAllReports.apex --target-org PBODevHub
```

**Expected Output:**
```
=== Report Audit Summary ===
Total Reports: 45
Successful: 43
Failed: 2
Using Deprecated Fields: 2

Reports Using Deprecated Fields:
  - Breach_Rate_Flows_wKr
  - Some_Other_Report

Unreferenced Reports:
  - Breaching_Soon_25_time_remaining_zDw
  - Breaching_today_b3w
  (... 16 more)
```

---

## 📊 Workflow: Testing Reports

### Step 1: Seed Test Data
```bash
sf apex run --file scripts/apex/seedTestData.apex --target-org PBODevHub
```

### Step 2: Run Report Audit
```bash
sf apex run --file scripts/apex/auditAllReports.apex --target-org PBODevHub
```

### Step 3: Manual Testing
1. Open PBODevHub in browser
2. Navigate to Reports → Flowdometer Reports
3. Run 5-10 sample reports to verify they display data correctly
4. Check dashboards → Flowdometer folder

### Step 4: Review Results
- Note which reports failed (need fixing)
- Note which reports use deprecated fields (update or delete)
- Note which reports are unreferenced (candidates for deletion)

### Step 5: Cleanup (when done)
```bash
sf apex run --file scripts/apex/cleanupTestData.apex --target-org PBODevHub
```

---

## 🎯 Best Practices

### ✅ DO:
- Run test data scripts in **dev/test orgs only** (not production!)
- Clean up test data when finished
- Use these scripts for report validation before deployment
- Add new utility scripts to this directory

### ❌ DON'T:
- Don't include scripts/ directory in `package.xml`
- Don't run test data scripts in production orgs
- Don't commit sensitive org data to these scripts
- Don't modify the main `force-app` directory from these scripts

---

## 🔒 Gitignore

The `scripts/` directory is **NOT** in `.gitignore`, so these utility scripts are version controlled. However, any personal/sensitive scripts should be added to `.gitignore`.

---

## 📝 Adding New Scripts

To add a new utility script:

1. **Create the file:**
   ```
   scripts/apex/myNewScript.apex
   ```

2. **Add a header comment:**
   ```apex
   /**
    * Description of what this script does
    * 
    * Run this in Anonymous Apex:
    * sf apex run --file scripts/apex/myNewScript.apex --target-org PBODevHub
    */
   ```

3. **Update this README** with documentation

4. **Test it!** Make sure it works before committing

---

## 🚀 Quick Reference

| Script | Purpose | Safe for Prod? |
|--------|---------|----------------|
| `seedTestData.apex` | Create sample data | ❌ No (dev only) |
| `cleanupTestData.apex` | Delete test data | ❌ No (dev only) |
| `auditAllReports.apex` | Test all reports | ✅ Yes (read-only) |

---

**Last Updated:** January 6, 2026  
**Maintainer:** Flowdometer Team
