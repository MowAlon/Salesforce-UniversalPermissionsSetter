public without sharing class UniversalPermissionsSetter {
    /* Assigns a given set of object and field permissions to all eligible objects and fields of a given Permission Set

        Originally designed to be scheduled periodically in order to maintain a "Read Everything" Permission Set

        Use: Pass in the API Name of a Permission Set along with Maps describing the desired permissions for all objects and fields.

        For example...

            private static String permission_set_name = 'Read_Everything';

            private static Map<String, Boolean> desired_object_permissions =
                    new Map<String, Boolean>{'PermissionsCreate'           => false,
                                             'PermissionsRead'             => true,
                                             'PermissionsEdit'             => false,
                                             'PermissionsDelete'           => false,
                                             'PermissionsViewAllRecords'   => true,
                                             'PermissionsModifyAllRecords' => false};

            private static Map<String, Boolean> desired_field_permissions =
                    new Map<String, Boolean>{'PermissionsRead' => true, // PermissionsRead MUST be true for Field Permissions
                                             'PermissionsEdit' => false};

            UniversalPermissionsSetter.set_permissions(permission_set_name, desired_object_permissions, desired_field_permissions);

        Tested by: ReadEverything_Scheduler_test
     */

    private static String               permission_set_name;
    private static Map<String, Boolean> desired_object_permissions;
    private static Map<String, Boolean> desired_field_permissions;

    private static Id          permission_set_id;
    private static Set<String> objects_already_setup_properly;

    private static Map<String, Schema.SObjectType> global_description = Schema.getGlobalDescribe();

    public static void set_permissions(String permission_set_name, Map<String, Boolean> desired_object_permissions, Map<String, Boolean> desired_field_permissions) {
        UniversalPermissionsSetter.permission_set_name        = permission_set_name;
        UniversalPermissionsSetter.desired_object_permissions = desired_object_permissions;
        UniversalPermissionsSetter.desired_field_permissions  = desired_field_permissions;

        permission_set_id = [SELECT Id FROM PermissionSet WHERE Name = :permission_set_name].Id;

        objects_already_setup_properly = objects_setup_properly_on_permission_set(permission_set_id);

        ObjectPermissions[] new_object_permissions = new_object_permissions();
        // Despite my best efforts, there are still many objects in this collection that can't have permissions set, so use the "All or Nothing" flag with false to skip them.
        if (!new_object_permissions.isEmpty()) {Database.insert(new_object_permissions, false);}

        FieldPermissions[] new_field_permissions = new_field_permissions();
        // In my experience, for reasons I don't fully understand, some fields' names are changed when added to the FieldPermissions object...
        // For example, Account.Site is added as Account.SiteId, even though you need to search for "Account.Site" to find it in a SOQL query.
        // This results in repeated attempts to add permissions for these fields even though they've already been added (and a "duplicate value" error).
        // So we also need to use a false "All or Nothing" flag here, just like when adding object permissions.

        if (Test.isRunningTest()) {new_field_permissions = new FieldPermissions[]{new_field_permissions[0], new_field_permissions[1], new_field_permissions[2]};}
        if (!new_field_permissions.isEmpty()) {BatchIt.now(new_field_permissions, false);} // BatchIt is a simple tool to batch large database changes. This line is equivalent to a batched version of Database.insert(new_field_permissions, false).
    }


    private static Set<String> objects_setup_properly_on_permission_set(Id permission_set_id) {
        Set<String> objects_already_setup_properly = new Set<String>{};

        ObjectPermissions[] existing_object_permissions = Database.query('SELECT SObjectType FROM ObjectPermissions WHERE ParentId = :permission_set_id AND ' + permissions_filter(desired_object_permissions));

        for (ObjectPermissions object_permissions : existing_object_permissions) {
            objects_already_setup_properly.add(object_permissions.SObjectType.toLowerCase());
        }

        return objects_already_setup_properly;
    }
    private static Set<String> fields_setup_properly_on_permission_set(Id permission_set_id) {
        Set<String> fields_already_setup_properly = new Set<String>{};

        FieldPermissions[] existing_field_permissions = Database.query('SELECT Field FROM FieldPermissions WHERE ParentId = :permission_set_id AND ' + permissions_filter(desired_field_permissions));

        for (FieldPermissions field_permissions : existing_field_permissions) {
            fields_already_setup_properly.add(field_permissions.Field.toLowerCase());
        }

        return fields_already_setup_properly;
    }

        private static String permissions_filter(Map<String, Boolean> permissions_setting_by_type) {
            String[] filters = new String[]{};

            for (String permission : permissions_setting_by_type.keySet()) {
                filters.add(permission + ' = ' + String.valueOf(permissions_setting_by_type.get(permission)));
            }

            return String.join(filters, ' AND ');
        }

    private static ObjectPermissions[] new_object_permissions() {
        ObjectPermissions[] new_object_permissions = new ObjectPermissions[]{};

        for (Schema.SObjectType object_type : global_description.values()) {
            Schema.DescribeSObjectResult object_description = object_type.getDescribe();
            String                       object_name        = object_description.getName().toLowerCase();

            /*
                There are a bunch of objects we want to avoid...
                Assuming this is being run by someone with Modify All access,
                isCreatable is a bit if a catchall to avoid many of these, like Custom Metadata, ChangeEvent, Feed, History, etc.
                There are a couple other things we need to more directly avoid.
                *** It's very possible there are others I missed - please let me know if you have better ideas for this part.
            */

            if (object_description.isCreateable() && !object_description.isCustomSetting() && !object_name.endsWith('share')) {
                add_object_permissions(new_object_permissions, object_name);
            }
        }

        return new_object_permissions;
    }
        private static void add_object_permissions(ObjectPermissions[] new_object_permissions, String object_name) {
            if (!objects_already_setup_properly.contains(object_name)) {
                ObjectPermissions object_permissions = new ObjectPermissions(SObjectType = object_name,
                                                                             ParentId = permission_set_id);

                for (String permission : desired_object_permissions.keySet()) {
                    object_permissions.put(permission, desired_object_permissions.get(permission));
                }

                new_object_permissions.add(object_permissions);
            }
        }

    private static FieldPermissions[] new_field_permissions() {
        FieldPermissions[] new_field_permissions  = new FieldPermissions[]{};

        Set<String> fields_already_setup_properly  = fields_setup_properly_on_permission_set(permission_set_id);

        // Before managing field permissions, we get the updated list of objects on the permission set because they may have changed
        for (String object_name : objects_setup_properly_on_permission_set(permission_set_id)) {
            add_field_permissions(new_field_permissions, object_name, fields_already_setup_properly);
        }

        return new_field_permissions;
    }
        private static void add_field_permissions(FieldPermissions[] new_field_permissions, String object_name, Set<String> fields_already_setup_properly) {
            for (Schema.SObjectField field : field_info_for_one_object(object_name)) {
                Schema.DescribeFieldResult field_description = field.getDescribe();
                String                     full_field_name   = (object_name + '.' + field_description.getName()).toLowerCase();

                if (permissions_should_be_added(fields_already_setup_properly, full_field_name, field_description)) {
                    FieldPermissions field_permissions = new FieldPermissions(SObjectType = full_field_name.left(full_field_name.indexOf('.')),
                                                                              ParentId    = permission_set_id,
                                                                              Field       = full_field_name);

                    for (String permission : desired_field_permissions.keySet()) {
                        field_permissions.put(permission, desired_field_permissions.get(permission));
                    }

                    new_field_permissions.add(field_permissions);
                }
            }
        }
            private static Schema.SObjectField[] field_info_for_one_object(String object_name) {
                return global_description.get(object_name).getDescribe().fields.getMap().values();
            }
            private static Boolean permissions_should_be_added(Set<String> fields_already_setup_properly, String full_field_name, Schema.DescribeFieldResult field_description) {
                return !fields_already_setup_properly.contains(full_field_name) &&
                    field_description.isPermissionable() &&
                    field_description.getCompoundFieldName() == null &&
                    !person_field(full_field_name);
            }
                private static Boolean person_field(String full_field_name_in_lower_case) {
                    return full_field_name_in_lower_case.startsWith('account.person') || full_field_name_in_lower_case.endsWith('__pc');
                }
}