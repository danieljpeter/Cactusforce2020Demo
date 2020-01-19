public without sharing class SalesBonusService {

    //delete [SELECT Id FROM Sales_Bonus__c];
    //SalesBonusService.updateBonuses();

    public static void updateBonuses() {

        //get all the CMDT rules
        List<Sales_Bonus_Rule__mdt> rules = [
            SELECT Id, Description__c, Start_Date__c, End_Date__c,
            Amount_Field__r.QualifiedApiName, User__r.QualifiedApiName, Date_Field__r.QualifiedApiName
            FROM Sales_Bonus_Rule__mdt
            WHERE Active__c = true
        ];

        //distinct sets of amount, user, date fields from CMDT so we can query later
        Set<String> amountFields = new Set<String>();
        Set<String> userFields = new Set<String>();
        Set<String> dateFields = new Set<String>();

        for (Sales_Bonus_Rule__mdt rule: rules) {
            amountFields.add(rule.Amount_Field__r.QualifiedApiName);
            userFields.add(rule.User__r.QualifiedApiName);
            dateFields.add(rule.Date_Field__r.QualifiedApiName);
        }

        //build a dynamic query of the fields from Opportunity which were references in the CMDT
        Set<String> allFields = new Set<String>();
        allFields.add('Id');
        allFields.addAll(amountFields);
        allFields.addAll(userFields);
        allFields.addAll(dateFields);
        String sFields = String.join(new List<String>(allFields), ',');
        String query = 'SELECT ' + sFields + ' FROM Opportunity';
        List<Opportunity> opps = Database.query(query);

        //empty list of bonuses to upsert
        List<Sales_Bonus__c> bonuses = new List<Sales_Bonus__c>();

        //apply all the rules too all the opps
        for (Opportunity opp: opps) {
            for (Sales_Bonus_Rule__mdt rule: rules) {
                Decimal amount = (Decimal)opp.get(rule.Amount_Field__r.QualifiedApiName);
                Date effectiveDate = (Date)opp.get(rule.Date_Field__r.QualifiedApiName);

                if ( amount == null || amount == 0 || (!isDateActive(rule, effectiveDate)) ) {
                    continue;
                }

                bonuses.add(new Sales_Bonus__c(
                    Amount__c = amount,
                    User__c = (Id)opp.get(rule.User__r.QualifiedApiName),
                    Effective_Date__c = effectiveDate,
                    Description__c = rule.Description__c,
                    Opportunity__c = opp.Id,
                    Unique_Key__c = opp.Id + '|' + rule.Id
                ));
            }
        }

        upsert bonuses Unique_Key__c;
    }

    private static Boolean isDateActive(Sales_Bonus_Rule__mdt rule, Date effectiveDate) {
        Boolean isActive = false;

        Boolean isAfterStart = (rule.Start_Date__c == null || effectiveDate >= rule.Start_Date__c);
        Boolean isBeforeEnd  = (rule.End_Date__c == null   || effectiveDate <= rule.End_Date__c);

        if (isAfterStart && isBeforeEnd) {
            isActive = true;
        }

        return isActive;
    }


}