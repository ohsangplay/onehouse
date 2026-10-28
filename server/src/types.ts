export type Env = {
  DB: D1Database;
};

export type Role = 'owner' | 'co_owner' | 'member';
export type MemberStatus = 'pending' | 'approved' | 'rejected' | 'revoked' | 'left';
export type CategoryType = 'common' | 'expense' | 'income';
export type TxType = 'income' | 'expense';

export type DeviceRow = {
  id: string;
  install_key_hash: string;
  token_hash: string;
  created_at: string;
  last_seen_at: string;
};

export type LedgerRow = {
  id: string;
  name: string;
  owner_member_id: string | null;
  invite_code: string;
  invite_code_updated_at: string;
  recovery_code_hash: string | null;
  recovery_code_updated_at: string | null;
  created_at: string;
  deleted_at: string | null;
};

export type MemberRow = {
  id: string;
  ledger_id: string;
  device_id: string;
  nickname: string;
  role: Role;
  status: MemberStatus;
  was_revoked: number;
  requested_at: string;
  decided_at: string | null;
  decided_by_member_id: string | null;
};

export type Vars = {
  device: DeviceRow;
  ledger: LedgerRow;
  member: MemberRow;
};

export type AppEnv = { Bindings: Env; Variables: Vars };
