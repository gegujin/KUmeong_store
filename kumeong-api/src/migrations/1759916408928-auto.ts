import { MigrationInterface, QueryRunner } from "typeorm";

export class Auto1759916408928 implements MigrationInterface {
    name = 'Auto1759916408928'

    public async up(queryRunner: QueryRunner): Promise<void> {
        await queryRunner.query(`CREATE TABLE \`users\` (\`id\` int NOT NULL AUTO_INCREMENT, \`universityName\` varchar(64) NULL, \`universityVerified\` tinyint NOT NULL DEFAULT 0, \`email\` varchar(120) NOT NULL, \`name\` varchar(100) NOT NULL, \`password_hash\` varchar(255) NOT NULL, \`reputation\` int NOT NULL DEFAULT '0', \`role\` enum ('USER', 'ADMIN') NOT NULL DEFAULT 'USER', \`created_at\` datetime(6) NOT NULL DEFAULT CURRENT_TIMESTAMP(6), \`updated_at\` datetime(6) NOT NULL DEFAULT CURRENT_TIMESTAMP(6) ON UPDATE CURRENT_TIMESTAMP(6), \`deleted_at\` datetime(6) NULL, UNIQUE INDEX \`IDX_97672ac88f789774dd47f7c8be\` (\`email\`), PRIMARY KEY (\`id\`)) ENGINE=InnoDB`);
        await queryRunner.query(`CREATE TABLE \`products\` (\`id\` varchar(36) NOT NULL, \`title\` varchar(100) NOT NULL, \`price\` int NOT NULL, \`status\` enum ('LISTED', 'RESERVED', 'SOLD') NOT NULL DEFAULT 'LISTED', \`description\` text NULL, \`category\` varchar(50) NULL, \`images\` text NULL, \`owner_id\` int NOT NULL, \`createdAt\` datetime(6) NOT NULL DEFAULT CURRENT_TIMESTAMP(6), \`updatedAt\` datetime(6) NOT NULL DEFAULT CURRENT_TIMESTAMP(6) ON UPDATE CURRENT_TIMESTAMP(6), INDEX \`IDX_product_price\` (\`price\`), INDEX \`IDX_product_createdAt\` (\`createdAt\`), INDEX \`IDX_product_owner\` (\`owner_id\`), PRIMARY KEY (\`id\`)) ENGINE=InnoDB`);
        await queryRunner.query(`CREATE TABLE \`notifications\` (\`id\` int NOT NULL AUTO_INCREMENT, \`userId\` bigint NOT NULL, \`type\` enum ('FRIEND_REQUEST_RECEIVED', 'FRIEND_REQUEST_ACCEPTED', 'FRIEND_REQUEST_REJECTED', 'FRIEND_REQUEST_CANCELLED', 'UNFRIENDED') NOT NULL, \`payload\` text NULL, \`createdAt\` datetime(6) NOT NULL DEFAULT CURRENT_TIMESTAMP(6), \`readAt\` datetime NULL, INDEX \`ix_notif_user_created\` (\`userId\`, \`createdAt\`), PRIMARY KEY (\`id\`)) ENGINE=InnoDB`);
        await queryRunner.query(`CREATE TABLE \`email_verifications\` (\`id\` varchar(36) NOT NULL, \`email\` varchar(255) NOT NULL, \`codeHash\` varchar(64) NOT NULL, \`expireAt\` datetime NOT NULL, \`remainingAttempts\` int NOT NULL DEFAULT '5', \`usedAt\` datetime NULL, \`lastSentAt\` datetime NULL, \`createdAt\` datetime(6) NOT NULL DEFAULT CURRENT_TIMESTAMP(6), \`updatedAt\` datetime(6) NOT NULL DEFAULT CURRENT_TIMESTAMP(6) ON UPDATE CURRENT_TIMESTAMP(6), INDEX \`IDX_44e5cfea68f87243cad38bb1b1\` (\`email\`), INDEX \`IDX_11acb33369827a079881ca230b\` (\`expireAt\`), PRIMARY KEY (\`id\`)) ENGINE=InnoDB`);
        await queryRunner.query(`CREATE TABLE \`friend_requests\` (\`id\` int NOT NULL AUTO_INCREMENT, \`fromUserId\` bigint NOT NULL, \`toUserId\` bigint NOT NULL, \`status\` enum ('PENDING', 'ACCEPTED', 'REJECTED', 'CANCELLED') NOT NULL DEFAULT 'PENDING', \`createdAt\` datetime(6) NOT NULL DEFAULT CURRENT_TIMESTAMP(6), \`decidedAt\` datetime NULL, UNIQUE INDEX \`uq_friend_req\` (\`fromUserId\`, \`toUserId\`), PRIMARY KEY (\`id\`)) ENGINE=InnoDB`);
        await queryRunner.query(`CREATE TABLE \`friends\` (\`id\` int NOT NULL AUTO_INCREMENT, \`userAId\` bigint NOT NULL, \`userBId\` bigint NOT NULL, \`createdAt\` datetime(6) NOT NULL DEFAULT CURRENT_TIMESTAMP(6), UNIQUE INDEX \`uq_friend_pair\` (\`userAId\`, \`userBId\`), PRIMARY KEY (\`id\`)) ENGINE=InnoDB`);
        await queryRunner.query(`CREATE TABLE \`chat_reads\` (\`id\` int NOT NULL AUTO_INCREMENT, \`userId\` bigint NOT NULL, \`peerId\` bigint NOT NULL, \`lastMessageId\` bigint NOT NULL DEFAULT '0', \`updatedAt\` datetime(6) NOT NULL DEFAULT CURRENT_TIMESTAMP(6) ON UPDATE CURRENT_TIMESTAMP(6), UNIQUE INDEX \`uq_read_pair\` (\`userId\`, \`peerId\`), PRIMARY KEY (\`id\`)) ENGINE=InnoDB`);
        await queryRunner.query(`CREATE TABLE \`chat_messages\` (\`id\` int NOT NULL AUTO_INCREMENT, \`userAId\` bigint NOT NULL, \`userBId\` bigint NOT NULL, \`senderId\` bigint NOT NULL, \`text\` text NOT NULL, \`createdAt\` datetime(6) NOT NULL DEFAULT CURRENT_TIMESTAMP(6), INDEX \`ix_pair_id\` (\`userAId\`, \`userBId\`, \`id\`), PRIMARY KEY (\`id\`)) ENGINE=InnoDB`);
        await queryRunner.query(`CREATE TABLE \`user_blocks\` (\`id\` int NOT NULL AUTO_INCREMENT, \`blockerId\` bigint NOT NULL, \`blockedId\` bigint NOT NULL, \`createdAt\` datetime(6) NOT NULL DEFAULT CURRENT_TIMESTAMP(6), UNIQUE INDEX \`uq_block\` (\`blockerId\`, \`blockedId\`), PRIMARY KEY (\`id\`)) ENGINE=InnoDB`);
        await queryRunner.query(`ALTER TABLE \`products\` ADD CONSTRAINT \`FK_47f06db8065c55a363b6db3ae82\` FOREIGN KEY (\`owner_id\`) REFERENCES \`users\`(\`id\`) ON DELETE CASCADE ON UPDATE NO ACTION`);
    }

    public async down(queryRunner: QueryRunner): Promise<void> {
        await queryRunner.query(`ALTER TABLE \`products\` DROP FOREIGN KEY \`FK_47f06db8065c55a363b6db3ae82\``);
        await queryRunner.query(`DROP INDEX \`uq_block\` ON \`user_blocks\``);
        await queryRunner.query(`DROP TABLE \`user_blocks\``);
        await queryRunner.query(`DROP INDEX \`ix_pair_id\` ON \`chat_messages\``);
        await queryRunner.query(`DROP TABLE \`chat_messages\``);
        await queryRunner.query(`DROP INDEX \`uq_read_pair\` ON \`chat_reads\``);
        await queryRunner.query(`DROP TABLE \`chat_reads\``);
        await queryRunner.query(`DROP INDEX \`uq_friend_pair\` ON \`friends\``);
        await queryRunner.query(`DROP TABLE \`friends\``);
        await queryRunner.query(`DROP INDEX \`uq_friend_req\` ON \`friend_requests\``);
        await queryRunner.query(`DROP TABLE \`friend_requests\``);
        await queryRunner.query(`DROP INDEX \`IDX_11acb33369827a079881ca230b\` ON \`email_verifications\``);
        await queryRunner.query(`DROP INDEX \`IDX_44e5cfea68f87243cad38bb1b1\` ON \`email_verifications\``);
        await queryRunner.query(`DROP TABLE \`email_verifications\``);
        await queryRunner.query(`DROP INDEX \`ix_notif_user_created\` ON \`notifications\``);
        await queryRunner.query(`DROP TABLE \`notifications\``);
        await queryRunner.query(`DROP INDEX \`IDX_product_owner\` ON \`products\``);
        await queryRunner.query(`DROP INDEX \`IDX_product_createdAt\` ON \`products\``);
        await queryRunner.query(`DROP INDEX \`IDX_product_price\` ON \`products\``);
        await queryRunner.query(`DROP TABLE \`products\``);
        await queryRunner.query(`DROP INDEX \`IDX_97672ac88f789774dd47f7c8be\` ON \`users\``);
        await queryRunner.query(`DROP TABLE \`users\``);
    }

}
