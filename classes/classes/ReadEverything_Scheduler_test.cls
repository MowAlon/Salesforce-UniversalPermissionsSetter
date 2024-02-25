@isTest
public class ReadEverything_Scheduler_test {

    @isTest static void test_UniversalPermissionsSetter_and_ReadEverything_Scheduler() {
        PermissionSet test_set = new PermissionSet(Label = 'Read Everything TEST', Name = 'Read_Everything_TEST');
        insert test_set;

        ReadEverything_Scheduler scheduler = new ReadEverything_Scheduler();
        scheduler.permission_set_name = 'Read_Everything_TEST';

        // Pre-assign a couple permissions just to prove there are no errors when some permissions already exist
        assign_permissions(scheduler, test_set.Id, new Map<String, Set<String>>{'Contact'     => new Set<String>{'Email', 'Phone'},
                                                                                'Opportunity' => new Set<String>{'Amount', 'NextStep'}});

        ObjectPermissions[] object_permissions_before = [SELECT Id FROM ObjectPermissions WHERE ParentId = :test_set.Id];
        FieldPermissions[]  field_permissions_before  = [SELECT Id FROM FieldPermissions  WHERE ParentId = :test_set.Id];

        Integer object_permissions_size_before = object_permissions_before.size();
        Integer field_permissions_size_before  = field_permissions_before.size();
        Assert.areEqual(2, object_permissions_size_before);
        Assert.areEqual(4, field_permissions_size_before);

        Test.startTest();
        scheduler.execute(null);
        Test.stopTest();

        ObjectPermissions[] object_permissions_after = [SELECT Id, PermissionsCreate, PermissionsRead, PermissionsEdit, PermissionsDelete, PermissionsViewAllRecords, PermissionsModifyAllRecords FROM ObjectPermissions WHERE ParentId = :test_set.Id];
        FieldPermissions[]  field_permissions_after  = [SELECT Id, PermissionsRead, PermissionsEdit FROM FieldPermissions  WHERE ParentId = :test_set.Id];

        Assert.isTrue(object_permissions_after.size() > object_permissions_size_before);
        Assert.areEqual(false, object_permissions_after[0].PermissionsCreate);
        Assert.areEqual(true,  object_permissions_after[0].PermissionsRead);
        Assert.areEqual(false, object_permissions_after[0].PermissionsEdit);
        Assert.areEqual(false, object_permissions_after[0].PermissionsDelete);
        Assert.areEqual(true,  object_permissions_after[0].PermissionsViewAllRecords);
        Assert.areEqual(false, object_permissions_after[0].PermissionsModifyAllRecords);

        Assert.isTrue(field_permissions_after.size() > field_permissions_size_before);
        Assert.areEqual(true,  field_permissions_after[0].PermissionsRead);
        Assert.areEqual(false, field_permissions_after[0].PermissionsEdit);
    }
        private static void assign_permissions(ReadEverything_Scheduler scheduler, Id permission_set_id, Map<String, Set<String>> fields_by_object) {
            insert_object_permissions(scheduler, permission_set_id, fields_by_object.keySet());
            insert_field_permissions(scheduler, permission_set_id, fields_by_object);
        }
            private static void insert_object_permissions(ReadEverything_Scheduler scheduler, Id permission_set_id, Set<String> fields) {
                ObjectPermissions[] all_object_permissions = new ObjectPermissions[]{};

                for (String object_name : fields) {
                    ObjectPermissions object_permissions = new ObjectPermissions(SObjectType = object_name,
                                                                                 ParentId    = permission_set_id);

                    for (String permission : scheduler.desired_object_permissions.keySet()) {
                        object_permissions.put(permission, scheduler.desired_object_permissions.get(permission));
                    }

                    all_object_permissions.add(object_permissions);
                }

                insert all_object_permissions;
            }
            private static void insert_field_permissions(ReadEverything_Scheduler scheduler, Id permission_set_id, Map<String, Set<String>> fields_by_object) {
                FieldPermissions[] all_field_permissions = new FieldPermissions[]{};

                for (String object_name : fields_by_object.keySet()) {
                    for (String field_name : fields_by_object.get(object_name)) {
                        FieldPermissions field_permissions = new FieldPermissions(SObjectType = object_name,
                                                                                  ParentId    = permission_set_id,
                                                                                  Field       = object_name + '.' + field_name);

                        for (String permission : scheduler.desired_field_permissions.keySet()) {
                            field_permissions.put(permission, scheduler.desired_field_permissions.get(permission));
                        }

                        all_field_permissions.add(field_permissions);
                    }
                }

                insert all_field_permissions;
            }
}