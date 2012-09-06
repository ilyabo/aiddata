_ = require "underscore"

# For most purposes several different names exist
# so we have to group them together
@groupPurposesByCode = (purposes, codeAttr = "code", nameAttr = "name", totalAmountAttr = "total_amount", totalNumAttr = "total_num") ->
  nopunct = (s) -> s.replace(/[\s'\.,-:;]/g, "")
  unique = {}
  for r in purposes
    if not r[codeAttr]? then r[codeAttr] = "00000"
    if not r[nameAttr]? then r[nameAttr] = "Unknown"

    r[nameAttr] = r[nameAttr].trim()
    uname = r[nameAttr].toUpperCase()
    
    if not(_.has(unique, r[codeAttr]))
      unique[r[codeAttr]] = r
    else
      oldname = unique[r[codeAttr]][nameAttr]
      # prefer not to use capitalized or shortened versions
      if oldname == oldname.toUpperCase() or nopunct(r[nameAttr]).length > nopunct(oldname).length
        old = unique[r[codeAttr]] 
        old[nameAttr] = r[nameAttr]
        if old[totalAmountAttr]?
          old[totalAmountAttr] += r[totalAmountAttr]
        if old[totalNumAttr]?
          old[totalNumAttr] += r[totalNumAttr]

  _.values(unique)




@provideWithPurposeCategories = (purposes, codeAttr = "code") ->
  for p in purposes
    p.category = switch p[codeAttr]?.substring(0, 1)
      when "1" then "Social Infrastructure and Services"
      when "2" then "Economic Infrastructure and Services"
      when "3" then "Production Sectors"
      when "4" then "Multi-Sector/Cross-Cutting"
      when "5" then "Commodity Aid And General Program Assistance"
      when "6" then "Action Relating to Debt"
      when "7" then "Humanitarian Aid"
      when "9" then "Other"

    p.subcategory = switch p[codeAttr]?.substring(0, 2)
      # ? Social Infrastructure and Services
      when "11" then "Education"
      when "12" then "Health"
      when "13" then "Population Policies/Programs and Reproductive Health"
      when "14" then "Water Supply and Sanitation"
      when "15" then "Government and Civil Society"
      when "16" then "Other Social Infrastructure and Services"

      # ￼Economic Infrastructure and Services
      when "21" then "Transport and Storage"
      when "22" then "Communications"
      when "23" then "Energy Generation and Supply"
      when "24" then "Banking and Financial Services"
      when "25" then "Business and Other Services"

      # Production Sectors
      when "31" then "Agriculture, Forestry, Fishing"
      when "32" then "Industry, Mining, Construction"

      # Multi-Sector/Cross-Cutting
      when "41" then "General Environmental Protection"
      when "42" then "Women"
      when "43" then "Other"

      # Commodity Aid And General Program Assistance
      when "51" then "General Budget Support"
      when "52" then "Development Aid/Food Security Assistance"
      when "53" then "Other Commodity Assistance"

      # Action Relating to Debt
      # Parent is the same
      #when "60" then "Action Relating to Debt"

      # Humanitarian Aid
      when "72" then "Emergency Response"
      when "73" then "Reconstruction Relief"
      when "74" then "Disaster Prevention and Preparedness"
      
      # Other?
      when "91" then "Administrative costs of Donors"
      when "92" then "Support to Non-Governmental Organizations and Government Organizations"
      when "93" then "Refugees in Donor Countries"
      when "99" then "Unallocated/Unspecified"


    # Should be subsubcategories, but they have no parent
    switch p[codeAttr]?.substring(0, 3)
      when "331" then p.subcategory = "Trade policy and regulations"
      when "332" then p.subcategory = "Tourism"



    p.subsubcategory = switch p[codeAttr]?.substring(0, 3)
      when "111" then "Education, level unspecified"
      when "112" then "Basic education"
      when "113" then "Secondary education"
      when "114" then "Post-secondary education"

      when "121" then "Health, general"
      when "122" then "Basic health"

      when "151" then "Government and civil society, general"
      when "152" then "Conflict prevention and resolution, peace and security"

      when "311" then "Agriculture"
      when "312" then "Forestry"
      when "313" then "Fishing"

      when "321" then "Industry"
      when "322" then "Mineral resources and mining"
      when "323" then "Construction"

      # No parent?
      #when "331" then "Trade policy and regulations"
      #when "332" then "Tourism"

  return purposes
