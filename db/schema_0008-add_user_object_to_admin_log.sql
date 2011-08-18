begin;

    ALTER TABLE admin_log DROP CONSTRAINT admin_log_object_type_check;

    ALTER TABLE admin_log ADD CONSTRAINT admin_log_object_type_check CHECK ( 
      object_type = 'problem'
      or object_type = 'update'
      or object_type = 'user'
    );


commit;
