use master
Go
/*
alter database  ConferenceMessaging
	set single_user with rollback immediate
GO
drop database ConferenceMessaging
go
*/

CREATE DATABASE ConferenceMessaging ON  
  PRIMARY ( NAME = N'ConferenceMessaging', FILENAME = N'C:\SQL\DATA\ConferenceMessaging.mdf' ,
		    SIZE = 1024MB , MAXSIZE = 1024MB)
 LOG ON 
		 ( NAME = N'ConferenceMessaging_log', FILENAME = N'C:\SQL\LOG\ConferenceMessaging_log.ldf' ,
		   SIZE = 100MB , MAXSIZE = 2048GB , FILEGROWTH = 100MB);
GO


use ConferenceMessaging
go
SELECT type_desc, size*8/1024 as [size (MB)],physical_name
FROM   sys.master_files
WHERE  database_id = db_id('ConferenceMessaging');
go
SELECT  suser_sname(sid) as [login]
FROM    sys.database_principals
WHERE   name = 'dbo'
GO
--Get the login of owner of the database from all database
SELECT suser_sname(owner_sid) as databaseOwner, name
FROM   sys.databases;


ALTER AUTHORIZATION ON Database::ConferenceMessaging to SA;
GO
CREATE SCHEMA Messages; --tables pertaining to the messages being sent
GO
CREATE SCHEMA Attendees; --tables pertaining to the attendees and how they can send messages
GO
SELECT name, USER_NAME(principal_id) as principal
FROM   sys.schemas
WHERE  name <> USER_NAME(principal_id);
GO
ALTER AUTHORIZATION ON SCHEMA::Messages To DBO;
GO
ALTER AUTHORIZATION ON SCHEMA::Attendees To DBO;
GO

CREATE SEQUENCE Messages.TopicIdGenerator
AS INT    
MINVALUE 10000 --starting value
NO MAXVALUE --technically will max out at max int
START WITH 10000 --value where the sequence will start, differs from min based on 
             --cycle property
INCREMENT BY 1 --number that is added the previous value
NO CYCLE --if setting is cycle, when it reaches max value it starts over
CACHE 100; --Use adjust number of values that SQL Server caches. Cached values would
          --be lost if the server is restarted, but keeping them in RAM makes access faster;

GO
SELECT NEXT VALUE FOR Messages.TopicIdGenerator AS TopicId
UNION ALL
SELECT NEXT VALUE FOR Messages.TopicIdGenerator AS TopicId
GO

CREATE SEQUENCE dbo.test 
GO
SELECT NEXT VALUE FOR dbo.test AS TestcId
GO

--To start a certain number add WITH <starting value literal>
ALTER SEQUENCE Messages.TopicIdGenerator RESTART;  
GO
Declare @range_first_value sql_variant, @range_last_value sql_variant,
        @sequence_increment sql_variant;
exec sp_sequence_get_range @sequence_name = N'Messages.TopicIdGenerator' 
     , @range_size = 100
     , @range_first_value = @range_first_value OUTPUT 
     , @range_last_value = @range_last_value OUTPUT 
     , @sequence_increment = @sequence_increment OUTPUT;
select cast(@range_first_value as int) as firstTopicId, 
       cast(@range_last_value as int) as lastTopicId, 
	   cast(@sequence_increment as int) as increment;

GO

SELECT start_value, increment, current_value
FROM sys.sequences 
WHERE schema_name(schema_id) = 'Messages'
   AND name = 'TopicIdGenerator';
GO
CREATE TABLE Attendees.AttendeeType ( 
	AttendeeType         varchar(20)  NOT NULL ,
	Description          varchar(60)  NOT NULL 
);
--As this is a non-editable table, we load the data here to
--start with
INSERT INTO Attendees.AttendeeType
VALUES ('Regular', 'Typical conference attendee'),
	   ('Speaker', 'Person scheduled to speak'),
	   ('Administrator','Manages System');

CREATE TABLE Attendees.MessagingUser ( 
	MessagingUserId      int IDENTITY ( 1,1 ) ,
	UserHandle           varchar(20)  NOT NULL ,
	AccessKeyValue       char(10)  NOT NULL ,
	AttendeeNumber       char(8)  NOT NULL ,
	FirstName            varchar(50)  NULL ,
	LastName             varchar(50)  NULL ,
	AttendeeType         varchar(20)  NOT NULL ,
	DisabledFlag         bit  NOT NULL ,
	RowCreateTime        datetime2(0)  NOT NULL ,
	RowLastUpdateTime    datetime2(0)  NOT NULL 
);
CREATE TABLE Attendees.UserConnection
( 
	UserConnectionId     int NOT NULL IDENTITY ( 1,1 ) ,
	ConnectedToMessagingUserId int  NOT NULL ,
	MessagingUserId      int  NOT NULL ,
	RowCreateTime        datetime2(0)  NOT NULL ,
	RowLastUpdateTime    datetime2(0)  NOT NULL 
);

CREATE TABLE Messages.Message ( 
	MessageId            int NOT NULL IDENTITY ( 1,1 ) ,
	RoundedMessageTime  as (dateadd(hour,datepart(hour,MessageTime),
	                               cast(cast(MessageTime as date)as datetime2(0)) ))
                                       PERSISTED,
	SentToMessagingUserId int  NULL ,
	MessagingUserId      int  NOT NULL ,
	Text                 nvarchar(200)  NOT NULL ,
	MessageTime          datetime2(0)  NOT NULL ,
	RowCreateTime        datetime2(0)  NOT NULL ,
	RowLastUpdateTime    datetime2(0)  NOT NULL 
);
CREATE TABLE Messages.MessageTopic ( 
	MessageTopicId       int NOT NULL IDENTITY ( 1,1 ) ,
	MessageId            int  NOT NULL ,
	UserDefinedTopicName nvarchar(30)  NULL ,
	TopicId              int  NOT NULL ,
	RowCreateTime        datetime2(0)  NOT NULL ,
	RowLastUpdateTime    datetime2(0)  NOT NULL 
);

CREATE TABLE Messages.Topic ( 
        TopicId int NOT NULL CONSTRAINT DFLTMessage_Topic_TopicId 
                                DEFAULT(NEXT VALUE FOR  dbo.TopicIdGenerator),
	Name                 nvarchar(30)  NOT NULL ,
	Description          varchar(60)  NOT NULL ,
	RowCreateTime        datetime2(0)  NOT NULL ,
	RowLastUpdateTime    datetime2(0)  NOT NULL 
);
go

ALTER TABLE Attendees.AttendeeType
     ADD CONSTRAINT PK_Attendees_AttendeeType PRIMARY KEY CLUSTERED (AttendeeType);

ALTER TABLE Attendees.MessagingUser
     ADD CONSTRAINT PK_Attendees_MessagingUser PRIMARY KEY CLUSTERED (MessagingUserId);

ALTER TABLE Attendees.UserConnection
     ADD CONSTRAINT PK_Attendees_UserConnection PRIMARY KEY CLUSTERED (UserConnectionId);
     
ALTER TABLE Messages.Message
     ADD CONSTRAINT PK_Messages_Message PRIMARY KEY CLUSTERED (MessageId);

ALTER TABLE Messages.MessageTopic
     ADD CONSTRAINT PK_Messages_MessageTopic PRIMARY KEY CLUSTERED (MessageTopicId);

ALTER TABLE Messages.Topic
     ADD CONSTRAINT PK_Messages_Topic PRIMARY KEY CLUSTERED (TopicId);
GO

CREATE TABLE TestConstraintName (TestConstraintNameId int PRIMARY KEY);
GO
SELECT constraint_name
FROM   information_schema.table_constraints
WHERE  table_schema = 'dbo'
  AND  table_name = 'TestConstraintName';
GO

ALTER TABLE Messages.Message
     ADD CONSTRAINT AK_Messages_Message_TimeUserAndText UNIQUE
      (RoundedMessageTime, MessagingUserId, Text);

ALTER TABLE Messages.Topic
     ADD CONSTRAINT AK_Messages_Topic_Name UNIQUE (Name);

ALTER TABLE Messages.MessageTopic
     ADD CONSTRAINT AK_Messages_MessageTopic_TopicAndMessage UNIQUE
      (MessageId, TopicId, UserDefinedTopicName);

ALTER TABLE Attendees.MessagingUser
     ADD CONSTRAINT AK_Attendees_MessagingUser_UserHandle UNIQUE (UserHandle);

ALTER TABLE Attendees.MessagingUser
     ADD CONSTRAINT AK_Attendees_MessagingUser_AttendeeNumber UNIQUE
     (AttendeeNumber);
     
ALTER TABLE Attendees.UserConnection
     ADD CONSTRAINT AK_Attendees_UserConnection_Users UNIQUE
     (MessagingUserId, ConnectedToMessagingUserId);
GO

SELECT OBJECT_SCHEMA_NAME(object_id) + '.' 
         + OBJECT_NAME(object_id) as object_name,
	   Name,is_primary_key, is_unique_constraint
FROM   sys.indexes
WHERE  OBJECT_SCHEMA_NAME(object_id) <> 'sys'
  AND  is_primary_key = 1 or is_unique_constraint = 1
ORDER BY object_name
GO


ALTER TABLE Attendees.MessagingUser
   ADD CONSTRAINT DFAttendees_MessagingUser_DisabledFlag
   DEFAULT (0) FOR DisabledFlag;

GO

SELECT 'ALTER TABLE ' + TABLE_SCHEMA + '.' +  TABLE_NAME + CHAR(13) + CHAR(10) +
       '    ADD CONSTRAINT DFLT' + TABLE_SCHEMA + '_' +  TABLE_NAME + '_' + COLUMN_NAME + CHAR(13) + CHAR(10) +
	   '    DEFAULT (SYSDATETIME()) FOR ' + COLUMN_NAME + ';'
FROM   INFORMATION_SCHEMA.COLUMNS
WHERE  COLUMN_NAME in ('RowCreateTime', 'RowLastUpdateTime')
  and  TABLE_SCHEMA in ('Messages','Attendees')
ORDER BY TABLE_SCHEMA, TABLE_NAME, COLUMN_NAME
GO

ALTER TABLE Attendees.MessagingUser
    ADD CONSTRAINT DFLTAttendees_MessagingUser_RowCreateTime
    DEFAULT (SYSDATETIME()) FOR RowCreateTime;
ALTER TABLE Attendees.MessagingUser
    ADD CONSTRAINT DFLTAttendees_MessagingUser_RowLastUpdateTime
    DEFAULT (SYSDATETIME()) FOR RowLastUpdateTime;
ALTER TABLE Attendees.UserConnection
    ADD CONSTRAINT DFLTAttendees_UserConnection_RowCreateTime
    DEFAULT (SYSDATETIME()) FOR RowCreateTime;
ALTER TABLE Attendees.UserConnection
    ADD CONSTRAINT DFLTAttendees_UserConnection_RowLastUpdateTime
    DEFAULT (SYSDATETIME()) FOR RowLastUpdateTime;
ALTER TABLE Messages.Message
    ADD CONSTRAINT DFLTMessages_Message_RowCreateTime
    DEFAULT (SYSDATETIME()) FOR RowCreateTime;
ALTER TABLE Messages.Message
    ADD CONSTRAINT DFLTMessages_Message_RowLastUpdateTime
    DEFAULT (SYSDATETIME()) FOR RowLastUpdateTime;
ALTER TABLE Messages.MessageTopic
    ADD CONSTRAINT DFLTMessages_MessageTopic_RowCreateTime
    DEFAULT (SYSDATETIME()) FOR RowCreateTime;
ALTER TABLE Messages.MessageTopic
    ADD CONSTRAINT DFLTMessages_MessageTopic_RowLastUpdateTime
    DEFAULT (SYSDATETIME()) FOR RowLastUpdateTime;
ALTER TABLE Messages.Topic
    ADD CONSTRAINT DFLTMessages_Topic_RowCreateTime
    DEFAULT (SYSDATETIME()) FOR RowCreateTime;
ALTER TABLE Messages.Topic
    ADD CONSTRAINT DFLTMessages_Topic_RowLastUpdateTime
    DEFAULT (SYSDATETIME()) FOR RowLastUpdateTime;
GO

ALTER TABLE Attendees.MessagingUser
       ADD CONSTRAINT FK__Attendees_MessagingUser$IsSent$Messages_Message
            FOREIGN KEY (AttendeeType) REFERENCES Attendees.AttendeeType(AttendeeType)
	    ON UPDATE CASCADE
            ON DELETE NO ACTION;

GO

ALTER TABLE Attendees.UserConnection
	ADD CONSTRAINT 
          FK__Attendees_MessagingUser$ConnectsToUserVia$Attendees_UserConnection 
        FOREIGN KEY (MessagingUserId) REFERENCES Attendees.MessagingUser(MessagingUserId)
	ON UPDATE NO ACTION
	ON DELETE CASCADE;
GO


SELECT '--Expected Error uncomment to see actual error'
BEGIN TRY
ALTER TABLE Attendees.UserConnection
	ADD CONSTRAINT 
          FK__Attendees_MessagingUser$IsConnectedToUserVia$Attendees_UserConnection 
        FOREIGN KEY  (ConnectedToMessagingUserId) 
                              REFERENCES Attendees.MessagingUser(MessagingUserId)
	ON UPDATE NO ACTION
	ON DELETE CASCADE;
END TRY
BEGIN CATCH
	SELECT ERROR_MESSAGE() AS LASTERRORMESSAGE
END CATCH

ALTER TABLE Attendees.UserConnection
	DROP CONSTRAINT 
          FK__Attendees_MessagingUser$ConnectsToUserVia$Attendees_UserConnection 
    
ALTER TABLE Attendees.UserConnection
	ADD CONSTRAINT 
          FK__Attendees_MessagingUser$ConnectsToUserVia$Attendees_UserConnection 
        FOREIGN KEY (MessagingUserId) REFERENCES Attendees.MessagingUser(MessagingUserId)
	ON UPDATE NO ACTION
	ON DELETE NO ACTION;

ALTER TABLE Attendees.UserConnection
	ADD CONSTRAINT 
          FK__Attendees_MessagingUser$IsConnectedToUserVia$Attendees_UserConnection 
        FOREIGN KEY  (ConnectedToMessagingUserId) 
                              REFERENCES Attendees.MessagingUser(MessagingUserId)
	ON UPDATE NO ACTION
	ON DELETE NO ACTION;
Go


ALTER TABLE Messages.Message
	ADD CONSTRAINT FK__Messages_MessagingUser$Sends$Messages_Message FOREIGN KEY 
	    (MessagingUserId) REFERENCES Attendees.MessagingUser(MessagingUserId)
	ON UPDATE NO ACTION
	ON DELETE NO ACTION;

ALTER TABLE Messages.Message
	ADD CONSTRAINT FK__Messages_MessagingUser$IsSent$Messages_Message FOREIGN KEY 
	    (SentToMessagingUserId) REFERENCES Attendees.MessagingUser(MessagingUserId)
	ON UPDATE NO ACTION
	ON DELETE NO ACTION;
GO



ALTER TABLE Messages.MessageTopic
	ADD CONSTRAINT 
           FK__Messages_Topic$CategorizesMessagesVia$Messages_MessageTopic FOREIGN KEY 
	     (TopicId) REFERENCES Messages.Topic(TopicId)
	ON UPDATE NO ACTION
	ON DELETE NO ACTION;
GO


ALTER TABLE Messages.MessageTopic
	ADD CONSTRAINT FK__Message$iscCategorizedVia$MessageTopic FOREIGN KEY 
	    (MessageId) REFERENCES Messages.Message(MessageId)
	ON UPDATE NO ACTION
	ON DELETE NO ACTION;
GO

ALTER TABLE Messages.Topic
   ADD CONSTRAINT CHK__Messages_Topic_Name_NotEmpty
       CHECK (LEN(RTRIM(Name)) > 0);

ALTER TABLE Messages.MessageTopic
   ADD CONSTRAINT CHK__Messages_MessageTopic_UserDefinedTopicName_NotEmpty
       CHECK (LEN(RTRIM(UserDefinedTopicName)) > 0);
GO

ALTER TABLE Attendees.MessagingUser 
  ADD CONSTRAINT CHK__Attendees_MessagingUser_UserHandle_LenthAndStart
     CHECK (LEN(Rtrim(UserHandle)) >= 5 
             AND LTRIM(UserHandle) LIKE '[a-z]' +
                            REPLICATE('[a-z1-9]',LEN(RTRIM(UserHandle)) -1));
GO

INSERT INTO Messages.Topic(TopicId, Name, Description)
VALUES (0,'User Defined','User Enters Their Own User Defined Topic');
GO

ALTER TABLE Messages.MessageTopic
  ADD CONSTRAINT CHK__Messages_MessageTopic_UserDefinedTopicName_NullUnlessUserDefined
   CHECK ((UserDefinedTopicName is NULL and TopicId <> 0)
              or (TopicId = 0 and UserDefinedTopicName is NOT NULL));
GO

CREATE TRIGGER Messages.MessageTopic$InsteadOfInsertTrigger
ON Messages.MessageTopic
INSTEAD OF INSERT AS
BEGIN
   SET NOCOUNT ON; --to avoid the rowcount messages
   SET ROWCOUNT 0; --in case the client has modified the rowcount

   DECLARE @msg varchar(2000),    --used to hold the error message
   --use inserted for insert or update trigger, deleted for update or delete trigger
   --count instead of @@rowcount due to merge behavior that sets @@rowcount to a number
   --that is equal to number of merged rows, not rows being checked in trigger
           @rowsAffected int = (select count(*) from inserted)
   --@rowsAffected = (select count(*) from deleted)

   --no need to continue on if no rows affected
   IF @rowsAffected = 0 RETURN;

   BEGIN TRY
          --[validation section]
          --[modification section]
          --<perform action>
          INSERT INTO Messages.MessageTopic (MessageId, UserDefinedTopicName,
	                                    TopicId,RowCreateTime,RowLastUpdateTime)
          SELECT MessageId, UserDefinedTopicName, TopicId, SYSDATETIME(), SYSDATETIME()
          FROM   inserted ;
   END TRY
   BEGIN CATCH
      IF @@trancount > 0
          ROLLBACK TRANSACTION;

      THROW; --will halt the batch or be caught by the caller's catch block

  END CATCH
END
GO

CREATE TRIGGER Messages.MessageTopic$InsteadOfUpdateTrigger
ON Messages.MessageTopic
INSTEAD OF UPDATE AS
BEGIN
   SET NOCOUNT ON; --to avoid the rowcount messages
   SET ROWCOUNT 0; --in case the client has modified the rowcount

   DECLARE @msg varchar(2000),    --used to hold the error message
   --use inserted for insert or update trigger, deleted for update or delete trigger
   --count instead of @@rowcount due to merge behavior that sets @@rowcount to a number
   --that is equal to number of merged rows, not rows being checked in trigger
           @rowsAffected int = (select count(*) from inserted)
   --@rowsAffected = (select count(*) from deleted)

   --no need to continue on if no rows affected
   IF @rowsAffected = 0 return;

   BEGIN TRY
          --[validation section]
          --[modification section]
          --<perform action>
         UPDATE MessageTopic 
	  SET   MessageId = Inserted.MessageId,
	        UserDefinedTopicName = Inserted.UserDefinedTopicName,
	        TopicId = Inserted.TopicId,
	        RowCreateTime = MessageTopic.RowCreateTime, --no changes allowed
	        RowLastUpdateTime = SYSDATETIME()
	  FROM  inserted 
	           JOIN Messages.MessageTopic 
			on inserted.MessageTopicId = MessageTopic.MessageTopicId;
   END TRY
   BEGIN CATCH
      IF @@trancount > 0
          ROLLBACK TRANSACTION;

      THROW --will halt the batch or be caught by the caller's catch block

  END CATCH
END
GO


CREATE TRIGGER Messages.Topic$InsteadOfInsertTrigger
ON Messages.Topic
INSTEAD OF INSERT AS
BEGIN
   DECLARE @msg varchar(2000),    --used to hold the error message
   --use inserted for insert or update trigger, deleted for update or delete trigger
   --count instead of @@rowcount due to merge behavior that sets @@rowcount to a number
   --that is equal to number of merged rows, not rows being checked in trigger
           @rowsAffected int = (select count(*) from inserted)
   --@rowsAffected = (select count(*) from deleted)

   --no need to continue on if no rows affected
   IF @rowsAffected = 0 RETURN;

   SET NOCOUNT ON; --to avoid the rowcount messages
   SET ROWCOUNT 0; --in case the client has modified the rowcount

   BEGIN TRY
          --[validation section]
          --[modification section]
          --<perform action>
          INSERT INTO Messages.Topic (TopicId, Name, Description,
										RowCreateTime,RowLastUpdateTime)
          SELECT TopicId, Name, Description,SYSDATETIME(), SYSDATETIME()
          FROM   inserted ;
   END TRY
   BEGIN CATCH
              IF @@trancount > 0
                  ROLLBACK TRANSACTION;

			  THROW;
     END CATCH
END
GO
CREATE TRIGGER Topic$InsteadOfUpdateTrigger
ON Messages.Topic
INSTEAD OF UPDATE AS
BEGIN
   DECLARE @msg varchar(2000),    --used to hold the error message
   --use inserted for insert or update trigger, deleted for update or delete trigger
   --count instead of @@rowcount due to merge behavior that sets @@rowcount to a number
   --that is equal to number of merged rows, not rows being checked in trigger
           @rowsAffected int = (select count(*) from inserted)
   --@rowsAffected = (select count(*) from deleted)

   --no need to continue on if no rows affected
   IF @rowsAffected = 0 return;

   SET NOCOUNT ON; --to avoid the rowcount messages
   SET ROWCOUNT 0; --in case the client has modified the rowcount

   BEGIN TRY
          --[validation section]
          --[modification section]
          --<perform action>
		  UPDATE Topic 
		  SET Name = Inserted.Name,
			  Description = Inserted.Description,
		      RowCreateTime = Topic.RowCreateTime, --no changes allowed
		      RowLastUpdateTime = SYSDATETIME()
		  FROM   inserted 
		            join Messages.Topic 
				on inserted.TopicId = Topic.TopicId;
   END TRY
   BEGIN CATCH
        IF @@trancount > 0
            ROLLBACK TRANSACTION;
			 
		THROW;

     END CATCH
END
GO

CREATE TRIGGER Message$InsteadOfInsertTrigger
ON Messages.Message
INSTEAD OF INSERT AS
BEGIN
   DECLARE @msg varchar(2000),    --used to hold the error message
   --use inserted for insert or update trigger, deleted for update or delete trigger
   --count instead of @@rowcount due to merge behavior that sets @@rowcount to a number
   --that is equal to number of merged rows, not rows being checked in trigger
           @rowsAffected int = (select count(*) from inserted)
   --@rowsAffected = (select count(*) from deleted)

   --no need to continue on if no rows affected
   IF @rowsAffected = 0 RETURN;

   SET NOCOUNT ON; --to avoid the rowcount messages
   SET ROWCOUNT 0; --in case the client has modified the rowcount

   BEGIN TRY
          --[validation section]
          --[modification section]
          --<perform action>
          INSERT INTO Messages.Message (SentToMessagingUserId, 
		                                MessagingUserId,Text, MessageTime, 
										RowCreateTime,RowLastUpdateTime)
          SELECT  SentToMessagingUserId, 
		          MessagingUserId,Text, MessageTime,SYSDATETIME(), SYSDATETIME()
          FROM   inserted ;
   END TRY
   BEGIN CATCH
              IF @@trancount > 0
                  ROLLBACK TRANSACTION;

			  THROW;

     END CATCH
END
GO
CREATE TRIGGER Message$InsteadOfUpdateTrigger
ON Messages.Message
INSTEAD OF UPDATE AS
BEGIN
   DECLARE @msg varchar(2000),    --used to hold the error message
   --use inserted for insert or update trigger, deleted for update or delete trigger
   --count instead of @@rowcount due to merge behavior that sets @@rowcount to a number
   --that is equal to number of merged rows, not rows being checked in trigger
           @rowsAffected int = (select count(*) from inserted)
   --@rowsAffected = (select count(*) from deleted)

   --no need to continue on if no rows affected
   IF @rowsAffected = 0 return;

   SET NOCOUNT ON; --to avoid the rowcount messages
   SET ROWCOUNT 0; --in case the client has modified the rowcount

   BEGIN TRY
          --[validation section]
          --[modification section]
          --<perform action>
		  UPDATE Message 
		  SET SentToMessagingUserId  = Inserted.SentToMessagingUserId,
			  MessagingUserId = Inserted.MessagingUserId,
			  Text = Inserted.Text,
			  MessageTime = Inserted.MessageTime, 
		      RowCreateTime = Message.RowCreateTime, --no changes allowed
		      RowLastUpdateTime = SYSDATETIME()
		  FROM   inserted 
		            join Messages.Message 
				on inserted.MessageId = Message.MessageId
   END TRY
   BEGIN CATCH
              IF @@trancount > 0
                  ROLLBACK TRANSACTION;

			  THROW;

     END CATCH
END
GO


CREATE TRIGGER MessagingUser$InsteadOfInsertTrigger
ON Attendees.MessagingUser
INSTEAD OF INSERT AS
BEGIN
   DECLARE @msg varchar(2000),    --used to hold the error message
   --use inserted for insert or update trigger, deleted for update or delete trigger
   --count instead of @@rowcount due to merge behavior that sets @@rowcount to a number
   --that is equal to number of merged rows, not rows being checked in trigger
           @rowsAffected int = (select count(*) from inserted)
   --@rowsAffected = (select count(*) from deleted)

   --no need to continue on if no rows affected
   IF @rowsAffected = 0 RETURN;

   SET NOCOUNT ON; --to avoid the rowcount messages
   SET ROWCOUNT 0; --in case the client has modified the rowcount

   BEGIN TRY
          --[validation section]
          --[modification section]
          --<perform action>
          INSERT INTO Attendees.MessagingUser (UserHandle, AccessKeyValue, AttendeeNumber, FirstName, LastName,
		                                AttendeeType, DisabledFlag,
										RowCreateTime,RowLastUpdateTime)
          SELECT UserHandle, AccessKeyValue, AttendeeNumber, FirstName, LastName,
		                                AttendeeType, DisabledFlag,SYSDATETIME(), SYSDATETIME()
          FROM   inserted ;
   END TRY
   BEGIN CATCH
              IF @@trancount > 0
                  ROLLBACK TRANSACTION;

			  THROW;

     END CATCH
END
GO

CREATE TRIGGER MessagingUser$UpdateRowControlsTrigger
ON Attendees.MessagingUser
AFTER UPDATE AS
BEGIN
   DECLARE @msg varchar(2000),    --used to hold the error message
   --use inserted for insert or update trigger, deleted for update or delete trigger
   --count instead of @@rowcount due to merge behavior that sets @@rowcount to a number
   --that is equal to number of merged rows, not rows being checked in trigger
           @rowsAffected int = (select count(*) from inserted)
   --@rowsAffected = (select count(*) from deleted)
	
   --no need to continue on if no rows affected
   IF @rowsAffected = 0 return;

   SET NOCOUNT ON; --to avoid the rowcount messages
   SET ROWCOUNT 0; --in case the client has modified the rowcount

   BEGIN TRY
          --[validation section]
          --[modification section]
	  UPDATE MessagingUser 
	  SET RowCreateTime = SYSDATETIME(),
	      RowLastUpdateTime = SYSDATETIME()
	  FROM   inserted 
	            join Attendees.MessagingUser
			on inserted.MessagingUserId = MessagingUser.MessagingUserId;
   END TRY
   BEGIN CATCH
        IF @@trancount > 0
            ROLLBACK TRANSACTION;

		THROW;
   END CATCH
END
GO

CREATE TRIGGER UserConnection$InsteadOfInsertTrigger
ON Attendees.UserConnection
INSTEAD OF INSERT AS
BEGIN
   DECLARE @msg varchar(2000),    --used to hold the error message
   --use inserted for insert or update trigger, deleted for update or delete trigger
   --count instead of @@rowcount due to merge behavior that sets @@rowcount to a number
   --that is equal to number of merged rows, not rows being checked in trigger
           @rowsAffected int = (select count(*) from inserted)
   --@rowsAffected = (select count(*) from deleted)

   --no need to continue on if no rows affected
   IF @rowsAffected = 0 RETURN;

   SET NOCOUNT ON; --to avoid the rowcount messages
   SET ROWCOUNT 0; --in case the client has modified the rowcount

   BEGIN TRY
          --[validation section]
          --[modification section]
          --<perform action>
          INSERT INTO Attendees.UserConnection (ConnectedToMessagingUserId, MessagingUserId, 
										RowCreateTime,RowLastUpdateTime)
          SELECT ConnectedToMessagingUserId, MessagingUserId, SYSDATETIME(), SYSDATETIME()
          FROM   inserted ;
   END TRY
   BEGIN CATCH
        IF @@trancount > 0
            ROLLBACK TRANSACTION;

		THROW;
   END CATCH
END
GO

--CREATE TABLE Attendees.UserConnection
--( 
--	UserConnectionId     int NOT NULL IDENTITY ( 1,1 ) ,
--	ConnectedToMessagingUserId int  NOT NULL ,
--	MessagingUserId      int  NOT NULL ,
--	RowCreateTime        datetime2(0)  NULL ,
--	RowLastUpdateTime    datetime2(0)  NULL 
--);
CREATE TRIGGER UserConnection$InsteadOfUpdateTrigger
ON Attendees.UserConnection
INSTEAD OF UPDATE AS
BEGIN

    DECLARE @msg varchar(2000),    --used to hold the error message
   --use inserted for insert or update trigger, deleted for update or delete trigger
   --count instead of @@rowcount due to merge behavior that sets @@rowcount to a number
   --that is equal to number of merged rows, not rows being checked in trigger
           @rowsAffected int = (select count(*) from inserted)
   --@rowsAffected = (select count(*) from deleted)

   --no need to continue on if no rows affected
   IF @rowsAffected = 0 return;

   SET NOCOUNT ON; --to avoid the rowcount messages
   SET ROWCOUNT 0; --in case the client has modified the rowcount

   BEGIN TRY
          --[validation section]
          --[modification section]
          --<perform action>
		  UPDATE UserConnection 
		  SET ConnectedToMessagingUserId = Inserted.ConnectedToMessagingUserId,
			  MessagingUserId = Inserted.MessagingUserId,
		      RowCreateTime = UserConnection.RowCreateTime, --no changes allowed
		      RowLastUpdateTime = SYSDATETIME()
		  FROM   inserted 
		            join Attendees.UserConnection 
				on inserted.UserConnectionId = UserConnection.UserConnectionId
   END TRY
   BEGIN CATCH
        IF @@trancount > 0
            ROLLBACK TRANSACTION;

		THROW;
   END CATCH
END
GO
 
go

--Messages schema 
EXEC sp_addextendedproperty @name = 'Description',
   @value = 'Messaging objects',
   @level0type = 'Schema', @level0name = 'Messages';

--Messages.Topic table
EXEC sp_addextendedproperty @name = 'Description',
   @value = ' Pre-defined topics for messages',
   @level0type = 'Schema', @level0name = 'Messages',
   @level1type = 'Table', @level1name = 'Topic';

--Messages.Topic.TopicId 
EXEC sp_addextendedproperty @name = 'Description',
   @value = 'Surrogate key representing a Topic',
   @level0type = 'Schema', @level0name = 'Messages',
   @level1type = 'Table', @level1name = 'Topic',
   @level2type = 'Column', @level2name = 'TopicId';

--Messages.Topic.Name
EXEC sp_addextendedproperty @name = 'Description',
   @value = 'The name of the topic',
   @level0type = 'Schema', @level0name = 'Messages',
   @level1type = 'Table', @level1name = 'Topic',
   @level2type = 'Column', @level2name = 'Name';

--Messages.Topic.Description
EXEC sp_addextendedproperty @name = 'Description',
   @value = 'Description of the purpose and utilization of the topics',
   @level0type = 'Schema', @level0name = 'Messages',
   @level1type = 'Table', @level1name = 'Topic',
   @level2type = 'Column', @level2name = 'Description';

--Messages.Topic.RowCreateTime
EXEC sp_addextendedproperty @name = 'Description',
   @value = 'Time when the row was created',
   @level0type = 'Schema', @level0name = 'Messages',
   @level1type = 'Table', @level1name = 'Topic',
   @level2type = 'Column', @level2name = 'RowCreateTime';

--Messages.Topic.RowLastUpdateTime
EXEC sp_addextendedproperty @name = 'Description',
   @value = 'Time when the row was last updated',
   @level0type = 'Schema', @level0name = 'Messages',
   @level1type = 'Table', @level1name = 'Topic',
   @level2type = 'Column', @level2name = 'RowLastUpdateTime';

EXEC sp_addextendedproperty @name = 'Description',
   @value = 'User Id of the user that is being sent a message',
   @level0type = 'Schema', @level0name = 'Messages',
   @level1type = 'Table', @level1name = 'Message',
   @level2type = 'Column', @level2name = 'SentToMessagingUserId';
   
--Messages.Message.MessagingUserId
EXEC sp_addextendedproperty @name = 'Description',
   @value ='User Id of the user that sent the message',
   @level0type = 'Schema', @level0name = 'Messages',
   @level1type = 'Table', @level1name = 'Message',
   @level2type = 'Column', @level2name =  'MessagingUserId';

--Messages.Message.Text 
EXEC sp_addextendedproperty @name = 'Description',
   @value = 'Text of the message being sent',
   @level0type = 'Schema', @level0name = 'Messages',
   @level1type = 'Table', @level1name = 'Message',
   @level2type = 'Column', @level2name = 'Text';

--Messages.Message.MessageTime 
EXEC sp_addextendedproperty @name = 'Description',
   @value = 'The time the message is sent, at a grain of one second',
   @level0type = 'Schema', @level0name = 'Messages',
   @level1type = 'Table', @level1name = 'Message',
   @level2type = 'Column', @level2name = 'MessageTime';
 
 --Messages.Message.RowCreateTime
EXEC sp_addextendedproperty @name = 'Description',
   @value = 'Time when the row was created',
   @level0type = 'Schema', @level0name = 'Messages',
   @level1type = 'Table', @level1name = 'Message',
   @level2type = 'Column', @level2name = 'RowCreateTime';

--Messages.Message.RowLastUpdateTime
EXEC sp_addextendedproperty @name = 'Description',
   @value = 'Time when the row was last updated',
   @level0type = 'Schema', @level0name = 'Messages',
   @level1type = 'Table', @level1name = 'Message',
   @level2type = 'Column', @level2name = 'RowLastUpdateTime';
   

--Messages.Message table
EXEC sp_addextendedproperty @name = 'Description',
   @value = 'Relates a message to a topic',
   @level0type = 'Schema', @level0name = 'Messages',
   @level1type = 'Table', @level1name = 'MessageTopic';

--Messages.Message.MessageTopicId 
EXEC sp_addextendedproperty @name = 'Description',
   @value = 'Surrogate key representing a MessageTopic',
   @level0type = 'Schema', @level0name = 'Messages',
   @level1type = 'Table', @level1name = 'MessageTopic',
   @level2type = 'Column', @level2name = 'MessageTopicId';
   
   --Messages.Message.MessageId 
EXEC sp_addextendedproperty @name = 'Description',
   @value = 'Surrogate key representing the message that is being associated with a topic',
   @level0type = 'Schema', @level0name = 'Messages',
   @level1type = 'Table', @level1name = 'MessageTopic',
   @level2type = 'Column', @level2name = 'MessageId';

--Messages.MessageUserDefinedTopicName 
EXEC sp_addextendedproperty @name = 'Description',
   @value = 'Allows the user to choose the “UserDefined” topic style and set their own topic ',
   @level0type = 'Schema', @level0name = 'Messages',
   @level1type = 'Table', @level1name = 'MessageTopic',
   @level2type = 'Column', @level2name = 'UserDefinedTopicName';

   --Messages.Message.TopicId
EXEC sp_addextendedproperty @name = 'Description',
   @value = 'Surrogate key representing the topic that is being associated with a message',
   @level0type = 'Schema', @level0name = 'Messages',
   @level1type = 'Table', @level1name = 'MessageTopic',
   @level2type = 'Column', @level2name = 'TopicId';

 --Messages.MessageTopic.RowCreateTime
EXEC sp_addextendedproperty @name = 'Description',
   @value = 'Time when the row was created',
   @level0type = 'Schema', @level0name = 'Messages',
   @level1type = 'Table', @level1name = 'MessageTopic',
   @level2type = 'Column', @level2name = 'RowCreateTime';

--Messages.MessageTopic.RowLastUpdateTime
EXEC sp_addextendedproperty @name = 'Description',
   @value = 'Time when the row was last updated',
   @level0type = 'Schema', @level0name = 'Messages',
   @level1type = 'Table', @level1name = 'MessageTopic',
   @level2type = 'Column', @level2name = 'RowLastUpdateTime';
GO

--Attendees schema 
EXEC sp_addextendedproperty @name = 'Description',
   @value = 'Attendee objects',
   @level0type = 'Schema', @level0name = 'Attendees';

--Attendees.AttendeeType table
EXEC sp_addextendedproperty @name = 'Description',
   @value = 'Domain of the different types of attendees that are supported',
   @level0type = 'Schema', @level0name = 'Attendees',
   @level1type = 'Table', @level1name = 'AttendeeType';

--Attendees.AttendeeType.AttendeeType
EXEC sp_addextendedproperty @name = 'Description',
   @value = 'Code representing a type of Attendee',
   @level0type = 'Schema', @level0name = 'Attendees',
   @level1type = 'Table', @level1name = 'AttendeeType',
   @level2type = 'Column', @level2name = 'AttendeeType';

--Attendees.AttendeeType.AttendeeType
EXEC sp_addextendedproperty @name = 'Description',
   @value = 'Brief description explaining the Attendee Type',
   @level0type = 'Schema', @level0name = 'Attendees',
   @level1type = 'Table', @level1name = 'AttendeeType',
   @level2type = 'Column', @level2name = 'Description';


--Attendees.MessagingUser table
EXEC sp_addextendedproperty @name = 'Description',
   @value = 'Represent a user of the messaging system, preloaded from another system with attendee information',
   @level0type = 'Schema', @level0name = 'Attendees',
   @level1type = 'Table', @level1name = 'MessagingUser';

--Attendees.MessagingUser.MessagingUserId
EXEC sp_addextendedproperty @name = 'Description',
   @value = 'Surrogate key representing a messaginguser',
   @level0type = 'Schema', @level0name = 'Attendees',
   @level1type = 'Table', @level1name = 'MessagingUser',
   @level2type = 'Column', @level2name = 'MessagingUserId';

--Attendees.MessagingUser.UserHandle
EXEC sp_addextendedproperty @name = 'Description',
   @value = 'The name the user wants to be known as. Initially pre-loaded with a value based on the persons first and last name, plus a integer value, changeable by the user',
   @level0type = 'Schema', @level0name = 'Attendees',
   @level1type = 'Table', @level1name = 'MessagingUser',
   @level2type = 'Column', @level2name = 'UserHandle';

--Attendees.MessagingUser.AccessKeyValue
EXEC sp_addextendedproperty @name = 'Description',
   @value = 'A password-like value given to the user on their badge to gain access',
   @level0type = 'Schema', @level0name = 'Attendees',
   @level1type = 'Table', @level1name = 'MessagingUser',
   @level2type = 'Column', @level2name = 'AccessKeyValue';

--Attendees.MessagingUser.AttendeeNumber
EXEC sp_addextendedproperty @name = 'Description',
   @value = 'The number that the attendee is given to identify themselves, printed on front of badge',
   @level0type = 'Schema', @level0name = 'Attendees',
   @level1type = 'Table', @level1name = 'MessagingUser',
   @level2type = 'Column', @level2name = 'AttendeeNumber';

--Attendees.MessagingUser.FirstName
EXEC sp_addextendedproperty @name = 'Description',
   @value = 'Name of the user printed on badge for people to see',
   @level0type = 'Schema', @level0name = 'Attendees',
   @level1type = 'Table', @level1name = 'MessagingUser',
   @level2type = 'Column', @level2name = 'FirstName';

--Attendees.MessagingUser.LastName
EXEC sp_addextendedproperty @name = 'Description',
   @value = 'Name of the user printed on badge for people to see',
   @level0type = 'Schema', @level0name = 'Attendees',
   @level1type = 'Table', @level1name = 'MessagingUser',
   @level2type = 'Column', @level2name = 'LastName';

--Attendees.MessagingUser.AttendeeType
EXEC sp_addextendedproperty @name = 'Description',
   @value = 'Used to give the user special priviledges, such as access to speaker materials, vendor areas, etc.',
   @level0type = 'Schema', @level0name = 'Attendees',
   @level1type = 'Table', @level1name = 'MessagingUser',
   @level2type = 'Column', @level2name = 'AttendeeType';

--Attendees.MessagingUser.DisabledFlag
EXEC sp_addextendedproperty @name = 'Description',
   @value = 'Indicates whether or not the user'' account has been disabled',
   @level0type = 'Schema', @level0name = 'Attendees',
   @level1type = 'Table', @level1name = 'MessagingUser',
   @level2type = 'Column', @level2name = 'DisabledFlag';

--Attendees.MessagingUser.RowCreateTime
EXEC sp_addextendedproperty @name = 'Description',
   @value = 'Time when the row was created',
   @level0type = 'Schema', @level0name = 'Attendees',
   @level1type = 'Table', @level1name = 'MessagingUser',
   @level2type = 'Column', @level2name = 'RowCreateTime';

--Attendees.MessagingUser.RowLastUpdateTime
EXEC sp_addextendedproperty @name = 'Description',
   @value = 'Time when the row was last updated',
   @level0type = 'Schema', @level0name = 'Attendees',
   @level1type = 'Table', @level1name = 'MessagingUser',
   @level2type = 'Column', @level2name = 'RowLastUpdateTime';
GO

--Attendees.UserConnection table
EXEC sp_addextendedproperty @name = 'Description',
   @value = 'Represents the connection of one user to another in order to filter results to a given set of users.',
   @level0type = 'Schema', @level0name = 'Attendees',
   @level1type = 'Table', @level1name = 'UserConnection';

--Attendees.MessagingUser.UserConnectionId
EXEC sp_addextendedproperty @name = 'Description',
   @value = 'Surrogate key representing a messaginguser',
   @level0type = 'Schema', @level0name = 'Attendees',
   @level1type = 'Table', @level1name = 'UserConnection',
   @level2type = 'Column', @level2name = 'UserConnectionId';

--Attendees.MessagingUser.UserConnectionId
EXEC sp_addextendedproperty @name = 'Description',
   @value = 'MessagingUserId of user that is going to connect themselves to another users ',
   @level0type = 'Schema', @level0name = 'Attendees',
   @level1type = 'Table', @level1name = 'UserConnection',
   @level2type = 'Column', @level2name = 'MessagingUserId';

--Attendees.MessagingUser.UserConnectionId
EXEC sp_addextendedproperty @name = 'Description',
   @value = 'MessagingUserId of user that is being connected to',
   @level0type = 'Schema', @level0name = 'Attendees',
   @level1type = 'Table', @level1name = 'UserConnection',
   @level2type = 'Column', @level2name = 'ConnectedToMessagingUserId';

--Attendees.MessagingUser.RowCreateTime
EXEC sp_addextendedproperty @name = 'Description',
   @value = 'Time when the row was created',
   @level0type = 'Schema', @level0name = 'Attendees',
   @level1type = 'Table', @level1name = 'UserConnection',
   @level2type = 'Column', @level2name = 'RowCreateTime';

--Attendees.MessagingUser.RowLastUpdateTime
EXEC sp_addextendedproperty @name = 'Description',
   @value = 'Time when the row was last updated',
   @level0type = 'Schema', @level0name = 'Attendees',
   @level1type = 'Table', @level1name = 'UserConnection',
   @level2type = 'Column', @level2name = 'RowLastUpdateTime';
GO

GO
SELECT objname, value
FROM   fn_listExtendedProperty ( 'Description',
                                 'Schema','Messages',
                                 'Table','Topic',
                                 'Column',null);
GO

SELECT SCHEMA_NAME, SCHEMA_OWNER
FROM   INFORMATION_SCHEMA.SCHEMATA
WHERE  SCHEMA_NAME <> SCHEMA_OWNER
GO

SELECT table_schema + '.' + TABLE_NAME as TABLE_NAME, COLUMN_NAME, 
	     --types that have a character or binary lenght
	case when DATA_TYPE IN ('varchar','char','nvarchar','nchar','varbinary')
		      then DATA_TYPE + case when character_maximum_length = -1 then '(max)'
                                            else '(' + CAST(character_maximum_length as 
                                                                    varchar(4)) + ')' end
		 --types with a datetime precision
		 when DATA_TYPE IN ('time','datetime2','datetimeoffset')
		      then DATA_TYPE + '(' + CAST(DATETIME_PRECISION as varchar(4)) + ')'
		--types with a precision/scale
		 when DATA_TYPE IN ('numeric','decimal')
		      then DATA_TYPE + '(' + CAST(NUMERIC_PRECISION as varchar(4)) + ',' + 
			                    CAST(NUMERIC_SCALE as varchar(4)) +  ')'
		 --timestamp should be reported as rowversion
		 when DATA_TYPE = 'timestamp' then 'rowversion'
		 --and the rest. Note, float is declared with a bit length, but is
		 --represented as either float or real in types 
		 else DATA_TYPE end as DECLARED_DATA_TYPE,
	COLUMN_DEFAULT
FROM   INFORMATION_SCHEMA.COLUMNS
ORDER BY TABLE_SCHEMA, TABLE_NAME,ORDINAL_POSITION
GO

SELECT TABLE_SCHEMA, TABLE_NAME, CONSTRAINT_NAME, CONSTRAINT_TYPE
FROM   INFORMATION_SCHEMA.table_constraints
WHERE  CONSTRAINT_SCHEMA in ('Attendees','Messages')
ORDER  BY  CONSTRAINT_SCHEMA, TABLE_NAME
GO
SELECT OBJECT_SCHEMA_NAME(parent_id) + '.' + OBJECT_NAME(parent_id) as TABLE_NAME, 
	   name as TRIGGER_NAME, 
	   case when is_instead_of_trigger = 1 then 'INSTEAD OF' else 'AFTER' End 
			as TRIGGER_FIRE_TYPE
FROM   sys.triggers
WHERE  type_desc = 'SQL_TRIGGER' --not a clr trigger
  and  parent_class = 1 --DML Triggers
ORDER BY TABLE_NAME, TRIGGER_NAME
GO

SELECT  TABLE_SCHEMA + '.' + TABLE_NAME as TABLE_NAME,
       TABLE_CONSTRAINTS.CONSTRAINT_NAME, CHECK_CLAUSE
FROM INFORMATION_SCHEMA.TABLE_CONSTRAINTS
	    JOIN INFORMATION_SCHEMA.CHECK_CONSTRAINTS
			  on TABLE_CONSTRAINTS.CONSTRAINT_SCHEMA = 
					CHECK_CONSTRAINTS.CONSTRAINT_SCHEMA
				 AND TABLE_CONSTRAINTS.CONSTRAINT_NAME = 
					CHECK_CONSTRAINTS.CONSTRAINT_NAME
