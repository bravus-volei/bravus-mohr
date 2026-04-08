-- ============================================================
-- BRAVUS MOHR APP — Schema Supabase
-- Execute no SQL Editor do Supabase (em ordem)
-- ============================================================

-- Habilitar extensão para UUID
CREATE EXTENSION IF NOT EXISTS "uuid-ossp";

-- ============================================================
-- TABELA: profiles (usuários do sistema)
-- ============================================================
CREATE TABLE profiles (
  id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
  auth_user_id UUID REFERENCES auth.users(id) ON DELETE CASCADE,
  name TEXT NOT NULL,
  email TEXT UNIQUE NOT NULL,
  role TEXT NOT NULL CHECK (role IN ('admin', 'tesoureiro', 'tecnico', 'atleta')),
  active BOOLEAN DEFAULT true,
  created_at TIMESTAMPTZ DEFAULT NOW(),
  updated_at TIMESTAMPTZ DEFAULT NOW()
);

-- ============================================================
-- TABELA: athletes (cadastro completo dos atletas)
-- ============================================================
CREATE TABLE athletes (
  id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
  profile_id UUID REFERENCES profiles(id) ON DELETE SET NULL,
  name TEXT NOT NULL,
  nickname TEXT,
  birth_date DATE,
  position TEXT CHECK (position IN ('Levantador', 'Líbero', 'Ponteiro', 'Central', 'Oposto', 'Outro')),
  jersey_number INTEGER,
  jersey_size TEXT CHECK (jersey_size IN ('PP', 'P', 'M', 'G', 'GG', 'XG')),
  phone TEXT,
  photo_url TEXT,
  document_url TEXT,
  status TEXT DEFAULT 'ativo' CHECK (status IN ('ativo', 'inativo', 'suspenso')),
  notes TEXT,
  monthly_fee_value DECIMAL(10,2),
  created_at TIMESTAMPTZ DEFAULT NOW(),
  updated_at TIMESTAMPTZ DEFAULT NOW()
);

-- ============================================================
-- TABELA: trainings (calendário de treinos e compromissos)
-- ============================================================
CREATE TABLE trainings (
  id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
  title TEXT NOT NULL,
  type TEXT DEFAULT 'treino' CHECK (type IN ('treino', 'jogo', 'torneio', 'viagem', 'outro')),
  date DATE NOT NULL,
  time TEXT,
  location TEXT,
  description TEXT,
  created_by UUID REFERENCES profiles(id),
  created_at TIMESTAMPTZ DEFAULT NOW()
);

-- ============================================================
-- TABELA: attendance (presença por treino)
-- ============================================================
CREATE TABLE attendance (
  id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
  training_id UUID REFERENCES trainings(id) ON DELETE CASCADE,
  athlete_id UUID REFERENCES athletes(id) ON DELETE CASCADE,
  status TEXT DEFAULT 'pendente' CHECK (status IN ('presente', 'falta', 'justificado', 'pendente')),
  justification TEXT,
  created_at TIMESTAMPTZ DEFAULT NOW(),
  updated_at TIMESTAMPTZ DEFAULT NOW(),
  UNIQUE(training_id, athlete_id)
);

-- ============================================================
-- TABELA: performance (avaliações de desempenho)
-- ============================================================
CREATE TABLE performance (
  id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
  training_id UUID REFERENCES trainings(id) ON DELETE CASCADE,
  athlete_id UUID REFERENCES athletes(id) ON DELETE CASCADE,
  score DECIMAL(3,1) CHECK (score >= 0 AND score <= 10),
  notes TEXT,
  evaluated_by UUID REFERENCES profiles(id),
  created_at TIMESTAMPTZ DEFAULT NOW(),
  updated_at TIMESTAMPTZ DEFAULT NOW(),
  UNIQUE(training_id, athlete_id)
);

-- ============================================================
-- TABELA: monthly_fees (mensalidades)
-- ============================================================
CREATE TABLE monthly_fees (
  id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
  athlete_id UUID REFERENCES athletes(id) ON DELETE CASCADE,
  year INTEGER NOT NULL,
  month INTEGER NOT NULL CHECK (month >= 1 AND month <= 12),
  amount DECIMAL(10,2) NOT NULL,
  status TEXT DEFAULT 'pendente' CHECK (status IN ('pago', 'pendente', 'isento', 'atrasado')),
  paid_at DATE,
  notes TEXT,
  created_at TIMESTAMPTZ DEFAULT NOW(),
  updated_at TIMESTAMPTZ DEFAULT NOW(),
  UNIQUE(athlete_id, year, month)
);

-- ============================================================
-- TABELA: extra_charges (cobranças extras — torneios, viagens)
-- ============================================================
CREATE TABLE extra_charges (
  id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
  title TEXT NOT NULL,
  description TEXT,
  amount DECIMAL(10,2) NOT NULL,
  due_date DATE,
  created_by UUID REFERENCES profiles(id),
  created_at TIMESTAMPTZ DEFAULT NOW()
);

-- ============================================================
-- TABELA: extra_charge_athletes (status por atleta)
-- ============================================================
CREATE TABLE extra_charge_athletes (
  id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
  extra_charge_id UUID REFERENCES extra_charges(id) ON DELETE CASCADE,
  athlete_id UUID REFERENCES athletes(id) ON DELETE CASCADE,
  status TEXT DEFAULT 'pendente' CHECK (status IN ('pago', 'pendente', 'nao_participa')),
  paid_at DATE,
  notes TEXT,
  created_at TIMESTAMPTZ DEFAULT NOW(),
  updated_at TIMESTAMPTZ DEFAULT NOW(),
  UNIQUE(extra_charge_id, athlete_id)
);

-- ============================================================
-- TABELA: announcements (avisos e comunicados)
-- ============================================================
CREATE TABLE announcements (
  id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
  title TEXT NOT NULL,
  content TEXT NOT NULL,
  type TEXT DEFAULT 'aviso' CHECK (type IN ('aviso', 'urgente', 'informativo')),
  published_at TIMESTAMPTZ DEFAULT NOW(),
  expires_at TIMESTAMPTZ,
  created_by UUID REFERENCES profiles(id),
  created_at TIMESTAMPTZ DEFAULT NOW()
);

-- ============================================================
-- TABELA: app_settings (configurações gerais)
-- ============================================================
CREATE TABLE app_settings (
  key TEXT PRIMARY KEY,
  value TEXT,
  updated_at TIMESTAMPTZ DEFAULT NOW()
);

INSERT INTO app_settings (key, value) VALUES
  ('team_name', 'Bravus Mohr'),
  ('default_monthly_fee', '80.00'),
  ('pix_key', ''),
  ('treasurer_phone', '');

-- ============================================================
-- ROW LEVEL SECURITY (RLS)
-- ============================================================

ALTER TABLE profiles ENABLE ROW LEVEL SECURITY;
ALTER TABLE athletes ENABLE ROW LEVEL SECURITY;
ALTER TABLE trainings ENABLE ROW LEVEL SECURITY;
ALTER TABLE attendance ENABLE ROW LEVEL SECURITY;
ALTER TABLE performance ENABLE ROW LEVEL SECURITY;
ALTER TABLE monthly_fees ENABLE ROW LEVEL SECURITY;
ALTER TABLE extra_charges ENABLE ROW LEVEL SECURITY;
ALTER TABLE extra_charge_athletes ENABLE ROW LEVEL SECURITY;
ALTER TABLE announcements ENABLE ROW LEVEL SECURITY;
ALTER TABLE app_settings ENABLE ROW LEVEL SECURITY;

-- Helper: pega o role do usuário logado
CREATE OR REPLACE FUNCTION get_user_role()
RETURNS TEXT AS $$
  SELECT role FROM profiles WHERE auth_user_id = auth.uid()
$$ LANGUAGE SQL SECURITY DEFINER;

-- Helper: pega o athlete_id do usuário logado
CREATE OR REPLACE FUNCTION get_athlete_id()
RETURNS UUID AS $$
  SELECT a.id FROM athletes a
  JOIN profiles p ON p.id = a.profile_id
  WHERE p.auth_user_id = auth.uid()
$$ LANGUAGE SQL SECURITY DEFINER;

-- PROFILES: todos leem o próprio, admin lê todos
CREATE POLICY "profiles_select" ON profiles FOR SELECT
  USING (auth_user_id = auth.uid() OR get_user_role() IN ('admin', 'tesoureiro'));

CREATE POLICY "profiles_insert" ON profiles FOR INSERT
  WITH CHECK (get_user_role() = 'admin');

CREATE POLICY "profiles_update" ON profiles FOR UPDATE
  USING (auth_user_id = auth.uid() OR get_user_role() = 'admin');

CREATE POLICY "profiles_delete" ON profiles FOR DELETE
  USING (auth_user_id = auth.uid()); -- só pode excluir a si mesmo

-- ATHLETES: admin/tesoureiro veem todos; tecnico vê nome/foto/número/posição; atleta vê só o próprio
CREATE POLICY "athletes_select_admin" ON athletes FOR SELECT
  USING (get_user_role() IN ('admin', 'tesoureiro', 'tecnico'));

CREATE POLICY "athletes_select_atleta" ON athletes FOR SELECT
  USING (get_user_role() = 'atleta' AND id = get_athlete_id());

CREATE POLICY "athletes_insert" ON athletes FOR INSERT
  WITH CHECK (get_user_role() = 'admin');

CREATE POLICY "athletes_update" ON athletes FOR UPDATE
  USING (get_user_role() = 'admin');

CREATE POLICY "athletes_delete" ON athletes FOR DELETE
  USING (get_user_role() = 'admin');

-- TRAININGS: todos leem, admin cria/edita/deleta
CREATE POLICY "trainings_select" ON trainings FOR SELECT USING (true);
CREATE POLICY "trainings_insert" ON trainings FOR INSERT WITH CHECK (get_user_role() = 'admin');
CREATE POLICY "trainings_update" ON trainings FOR UPDATE USING (get_user_role() = 'admin');
CREATE POLICY "trainings_delete" ON trainings FOR DELETE USING (get_user_role() = 'admin');

-- ATTENDANCE: admin gerencia todos; tecnico lê; atleta vê o próprio
CREATE POLICY "attendance_select_admin" ON attendance FOR SELECT
  USING (get_user_role() IN ('admin', 'tecnico'));

CREATE POLICY "attendance_select_atleta" ON attendance FOR SELECT
  USING (get_user_role() = 'atleta' AND athlete_id = get_athlete_id());

CREATE POLICY "attendance_insert" ON attendance FOR INSERT
  WITH CHECK (get_user_role() = 'admin');

CREATE POLICY "attendance_update" ON attendance FOR UPDATE
  USING (get_user_role() = 'admin');

-- PERFORMANCE: admin e tecnico gerenciam; atleta vê o próprio
CREATE POLICY "performance_select_admin" ON performance FOR SELECT
  USING (get_user_role() IN ('admin', 'tecnico'));

CREATE POLICY "performance_select_atleta" ON performance FOR SELECT
  USING (get_user_role() = 'atleta' AND athlete_id = get_athlete_id());

CREATE POLICY "performance_insert" ON performance FOR INSERT
  WITH CHECK (get_user_role() IN ('admin', 'tecnico'));

CREATE POLICY "performance_update" ON performance FOR UPDATE
  USING (get_user_role() IN ('admin', 'tecnico'));

-- MONTHLY FEES: admin e tesoureiro gerenciam; atleta vê o próprio
CREATE POLICY "fees_select_admin" ON monthly_fees FOR SELECT
  USING (get_user_role() IN ('admin', 'tesoureiro'));

CREATE POLICY "fees_select_atleta" ON monthly_fees FOR SELECT
  USING (get_user_role() = 'atleta' AND athlete_id = get_athlete_id());

CREATE POLICY "fees_insert" ON monthly_fees FOR INSERT
  WITH CHECK (get_user_role() IN ('admin', 'tesoureiro'));

CREATE POLICY "fees_update" ON monthly_fees FOR UPDATE
  USING (get_user_role() IN ('admin', 'tesoureiro'));

-- EXTRA CHARGES: admin e tesoureiro gerenciam; atleta vê o próprio
CREATE POLICY "extra_select_admin" ON extra_charges FOR SELECT
  USING (get_user_role() IN ('admin', 'tesoureiro'));

CREATE POLICY "extra_athletes_select_admin" ON extra_charge_athletes FOR SELECT
  USING (get_user_role() IN ('admin', 'tesoureiro'));

CREATE POLICY "extra_athletes_select_atleta" ON extra_charge_athletes FOR SELECT
  USING (get_user_role() = 'atleta' AND athlete_id = get_athlete_id());

CREATE POLICY "extra_insert" ON extra_charges FOR INSERT
  WITH CHECK (get_user_role() IN ('admin', 'tesoureiro'));

CREATE POLICY "extra_update" ON extra_charges FOR UPDATE
  USING (get_user_role() IN ('admin', 'tesoureiro'));

CREATE POLICY "extra_athletes_insert" ON extra_charge_athletes FOR INSERT
  WITH CHECK (get_user_role() IN ('admin', 'tesoureiro'));

CREATE POLICY "extra_athletes_update" ON extra_charge_athletes FOR UPDATE
  USING (get_user_role() IN ('admin', 'tesoureiro'));

-- ANNOUNCEMENTS: todos leem; admin cria
CREATE POLICY "announcements_select" ON announcements FOR SELECT USING (true);
CREATE POLICY "announcements_insert" ON announcements FOR INSERT WITH CHECK (get_user_role() = 'admin');
CREATE POLICY "announcements_update" ON announcements FOR UPDATE USING (get_user_role() = 'admin');
CREATE POLICY "announcements_delete" ON announcements FOR DELETE USING (get_user_role() = 'admin');

-- APP SETTINGS: todos leem; admin edita
CREATE POLICY "settings_select" ON app_settings FOR SELECT USING (true);
CREATE POLICY "settings_update" ON app_settings FOR UPDATE USING (get_user_role() = 'admin');

-- ============================================================
-- STORAGE: bucket para fotos
-- Execute separadamente no Storage do Supabase
-- ============================================================
-- INSERT INTO storage.buckets (id, name, public) VALUES ('athlete-photos', 'athlete-photos', false);
-- CREATE POLICY "photos_select" ON storage.objects FOR SELECT USING (get_user_role() IN ('admin', 'tecnico') OR auth.uid()::text = (storage.foldername(name))[1]);
-- CREATE POLICY "photos_insert" ON storage.objects FOR INSERT WITH CHECK (get_user_role() = 'admin');
