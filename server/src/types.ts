export type Env = {
  DB: D1Database;
  /** 비워두면 브라우저에서 API를 못 쓴다 (운영). 로컬·CI 웹 미리보기에서만 "*" 등으로 설정 */
  ALLOW_WEB_ORIGINS?: string;
  /** 스토어 출시 후 채우면 안내 페이지 버튼이 링크로 바뀐다 */
  APP_STORE_URL?: string;
  PLAY_STORE_URL?: string;
  /** 한지붕 메모 스토어 주소 */
  MEMO_APP_STORE_URL?: string;
  MEMO_PLAY_STORE_URL?: string;
};

/** 공간 종류: 한지붕 가계부(budget) / 한지붕 메모(memo). DB 테이블 이름은 처음 만든 가계부 기준(ledgers)을 그대로 쓴다 */
export type SpaceKind = 'budget' | 'memo';

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
  kind: SpaceKind;
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
