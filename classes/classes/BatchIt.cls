public class BatchIt implements Database.Batchable<SObject>, Iterable<SObject>, Iterator<SObject> {
    /* Takes a list of SObjects and runs the desired DML action in a batch.

        Usage: Database.executeBatch(new BatchIt(<SObject List>, <'insert', 'update', or 'upsert'>, [optional all_or_nothing Boolean]), [optional batch size Integer]);
        Example:
            Database.executeBatch(new BatchIt(account_records, 'insert'), 10);

            ... or the quick version:
                BatchIt.now(account_records);
    */

    public static void now(SObject[] records)                                             {Database.executeBatch(new BatchIt(records, 'upsert'));}
    public static void now(SObject[] records, Boolean all_or_nothing)                     {Database.executeBatch(new BatchIt(records, 'upsert', all_or_nothing));}
    public static void now(SObject[] records, Boolean all_or_nothing, Integer batch_size) {Database.executeBatch(new BatchIt(records, 'upsert', all_or_nothing), batch_size);}
    public static void now(SObject[] records, Integer batch_size)                         {Database.executeBatch(new BatchIt(records, 'upsert'), batch_size);}

    SObject[] records;
    String    action;
    Boolean   all_or_nothing;
    Integer   index = 0;

    public BatchIt(SObject[] records, String action) {this(records, action, true);}
    public BatchIt(SObject[] records, String action, Boolean all_or_nothing) {
        this.records        = records;
        this.action         = action;
        this.all_or_nothing = all_or_nothing;
    }

    // public void execute(SchedulableContext context) {Database.executeBatch(this);} // Must implement 'Schedulable' to be schedulable

    public Iterator<SObject> iterator() {return this;}
    public Boolean hasNext()            {return index < records.size();}
    public SObject next()               {return records[index++];}

    public Iterable<SObject> start(Database.BatchableContext context) {return this;}

    public void  execute(Database.BatchableContext context, List<SObject> batch_of_records) {
        switch on action {
            when 'insert' {Database.insert(batch_of_records, all_or_nothing);}
            when 'update' {Database.update(batch_of_records, all_or_nothing);}
            when 'upsert' {Database.upsert(batch_of_records, all_or_nothing);}
        }
    }

    public void finish(Database.BatchableContext context) {}
}