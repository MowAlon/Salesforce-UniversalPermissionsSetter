global class ReadEverything_Scheduler implements Schedulable {
    @testVisible private String permission_set_name = 'Read_Everything';

    @testVisible private Map<String, Boolean> desired_object_permissions =
            new Map<String, Boolean>{'PermissionsCreate'           => false,
                                     'PermissionsRead'             => true,
                                     'PermissionsEdit'             => false,
                                     'PermissionsDelete'           => false,
                                     'PermissionsViewAllRecords'   => true,
                                     'PermissionsModifyAllRecords' => false};

    @testVisible private Map<String, Boolean> desired_field_permissions =
            new Map<String, Boolean>{'PermissionsRead' => true,
                                     'PermissionsEdit' => false};

    global void execute(SchedulableContext SC) {
        UniversalPermissionsSetter.set_permissions(permission_set_name, desired_object_permissions, desired_field_permissions);
    }
}