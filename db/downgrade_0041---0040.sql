begin;
ALTER TABLE user_body_permissions
ADD CONSTRAINT user_body_permissions_permission_type_check
CHECK (
    permission_type='moderate' or
    -- for future expansion --
    permission_type='admin'
);
commit;
