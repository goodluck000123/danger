-- ========================================================
-- 화성시남부신문고 Supabase 테이블 스키마 & 보안 정책 (RLS)
-- Supabase 대시보드 -> SQL Editor 에서 전체 복사 후 실행(Run)하세요.
-- ========================================================

-- 1. 신문고 접수 내역 테이블 생성 (기존 테이블이 있으면 삭제하지 않고 확인)
CREATE TABLE IF NOT EXISTS public.incidents (
  id TEXT PRIMARY KEY,                       -- 접수 고유 번호 (예: HS-20261008-1234)
  location TEXT NOT NULL,                    -- 발생 장소/위치
  category TEXT NOT NULL,                    -- 위험 유형 (낙상/파손/전기 등)
  description TEXT NOT NULL,                 -- 신고 상세 내용
  reporter TEXT DEFAULT '복지관 직원',      -- 신고자 이름/부서
  status TEXT DEFAULT 'pending',             -- 처리 상태: pending(접수), in_progress(조치중), completed(조치완료)
  action_note TEXT,                          -- 시설관리자 조치 내용 메모
  action_date TIMESTAMPTZ,                   -- 조치 완료 일시
  photo TEXT,                                -- 사진 데이터 (압축 Base64 또는 URL)
  created_at TIMESTAMPTZ DEFAULT NOW()       -- 접수 일시
);

-- 2. 검색 및 최신순 정렬을 위한 인덱스 생성
CREATE INDEX IF NOT EXISTS idx_incidents_created_at ON public.incidents (created_at DESC);
CREATE INDEX IF NOT EXISTS idx_incidents_status ON public.incidents (status);

-- 3. Row Level Security (RLS) 활성화
ALTER TABLE public.incidents ENABLE ROW LEVEL SECURITY;

-- 4. 누구나 신고(Insert)하고, 관리자/직원이 조회(Select) 및 상태변경(Update), 삭제(Delete)할 수 있도록 정책 허용
-- (내부 인트라넷/복지관 간편 신문고용 Anon 정책)
DROP POLICY IF EXISTS "누구나 안전신문고 조회 가능" ON public.incidents;
CREATE POLICY "누구나 안전신문고 조회 가능"
ON public.incidents FOR SELECT
USING (true);

DROP POLICY IF EXISTS "누구나 안전신문고 접수 가능" ON public.incidents;
CREATE POLICY "누구나 안전신문고 접수 가능"
ON public.incidents FOR INSERT
WITH CHECK (true);

DROP POLICY IF EXISTS "누구나 안전신문고 상태 변경 가능" ON public.incidents;
CREATE POLICY "누구나 안전신문고 상태 변경 가능"
ON public.incidents FOR UPDATE
USING (true);

DROP POLICY IF EXISTS "누구나 안전신문고 삭제 가능" ON public.incidents;
CREATE POLICY "누구나 안전신문고 삭제 가능"
ON public.incidents FOR DELETE
USING (true);

-- 5. 실시간 동기화 (Supabase Realtime) 활성화
-- 직원이 폰으로 접수하면 관리자 PC 화면에 새로고침 없이 즉시 나타나게 합니다.
ALTER PUBLICATION supabase_realtime ADD TABLE public.incidents;

-- 6. 기본 샘플 데이터 입력 (테이블이 비어있을 경우에만 추가)
INSERT INTO public.incidents (id, location, category, description, reporter, status, action_note, action_date, created_at)
VALUES 
  ('HS-2026-1008-01', '본관 2층 프로그램실 203호 복도 앞', '낙상/바닥 미끄럼', '복도 바닥 미끄럼 방지 매트 모서리가 살짝 들떠 있어서 보행차를 미시는 어르신들이 걸려 넘어지실 위험이 있습니다.', '평생교육팀 이복지', 'pending', NULL, NULL, NOW()),
  ('HS-2026-1008-02', '지하 1층 경로식당 퇴식구 주변', '낙상/바닥 미끄럼', '식사 배식 후 식기 반납대 바닥에 물기가 고여 미끄럽습니다. 조치 및 안내 표지판 설치 부탁드립니다.', '영양위생팀 박조리', 'in_progress', '현장 미끄럼주의 안전표지판 2개 배치 완료, 수시 건식 걸레질 진행 중', NOW(), NOW() - INTERVAL '2 hours'),
  ('HS-2026-1007-03', '1층 어르신 전용 남성 화장실 세면대', '시설/비품 파손', '세면대 온수 수전 레버가 헐거워져 헛돌고 물이 조금씩 샙니다.', '안내데스크 최직원', 'completed', '수전 카트리지 및 패킹 교체 수리 완료. 정상 작동 확인.', NOW() - INTERVAL '1 day', NOW() - INTERVAL '1 day')
ON CONFLICT (id) DO NOTHING;
