# Database Analysis Report

## Executive Summary

The database examination reveals that the "1500Gebaren" label is stored correctly in the `form_data` table and the LIKE query pattern is working as expected. The system found **289 rows** containing the "1500Gebaren" label.

## Key Findings

### 1. Table Structure
- The `form_data` table has a `labels` column of type `varchar(255)`
- Labels are stored as JSON arrays (e.g., `["1500Gebaren","TYDbase","TYDapp"]`)
- The table contains 22,031 total rows with 16,385 rows having labels

### 2. Label Format
Labels are stored as JSON arrays with quoted strings:
```json
["1500Gebaren","TYDbase","TYDapp"]
["TYDbase","1500Gebaren"]
["GGMD/GGZ","TYDbase","HealthHolland","1500Gebaren"]
```

### 3. Search Pattern Analysis
All search patterns for "1500Gebaren" return the same count (289 rows):
- `%1500Gebaren%` - 289 rows
- `%"1500Gebaren"%` - 289 rows  
- `%1500gebaren%` - 289 rows (case insensitive)
- `%1500%` - 289 rows (number only)

### 4. Sample Data with "1500Gebaren" Label
| ID | Glos | Thema | Labels |
|---|---|---|---|
| 40130 | GOED-A | VRAAGWOORDEN | ["1500Gebaren","TYDbase","TYDapp"] |
| 40137 | WAT-A | VRAAGWOORDEN | ["1500Gebaren","TYDbase","TYDapp"] |
| 40158 | LANG-A | BEGROETINGEN EN ONTMOETING | ["TYDbase","1500Gebaren"] |
| 40177 | BEHANDELEN | INTAKE EN DOSSIER | ["GGMD/GGZ","TYDbase","HealthHolland","1500Gebaren"] |
| 40231 | RELATIE-A | INTAKE EN DOSSIER | ["TYDbase","GGMD/GGZ","1500Gebaren"] |

## Current Query Pattern Effectiveness

The current LIKE query pattern `f.labels LIKE '%"1500Gebaren"%'` used in the download system is working correctly:

```sql
SELECT f.id, f.glos, f.thema, f.labels 
FROM form_data f 
WHERE f.labels LIKE '%"1500Gebaren"%'
```

This pattern:
- ✅ Successfully matches 289 rows
- ✅ Works with JSON array format
- ✅ Handles different label positions within arrays
- ✅ Is case-sensitive (which appears to be intentional)

## Recommendations

1. **Current Implementation is Correct**: The LIKE query with `%"1500Gebaren"%` is working properly and finding all relevant records.

2. **Performance**: For better performance with larger datasets, consider:
   - Adding an index on the `labels` column
   - Using MySQL's JSON functions for more precise matching

3. **Alternative Query Approach** (if needed):
   ```sql
   SELECT f.id, f.glos, f.thema, f.labels 
   FROM form_data f 
   WHERE JSON_CONTAINS(f.labels, '"1500Gebaren"')
   ```

4. **Data Integrity**: There's one anomalous entry with `["[object Object]","[object Object]"]` that should be investigated.

## Conclusion

The database structure and query patterns are working correctly. The "1500Gebaren" label is properly stored and searchable, with 289 matching records found. The current implementation should successfully filter and download videos with this label.