-- Tabla y funciones para guardar las respuestas del cuestionario de Strada Motor.
-- Pégalo entero en Supabase → SQL Editor → Run.

create table if not exists public.cuestionarios (
  id          uuid primary key,
  proyecto    text not null,
  estado      text not null default 'borrador',   -- 'borrador' mientras rellenan, 'enviado' al pulsar Enviar
  texto       text,                               -- respuestas en texto legible
  respuestas  jsonb not null default '{}'::jsonb, -- respuestas en bruto
  creado      timestamptz not null default now(),
  actualizado timestamptz not null default now(),
  enviado     timestamptz
);

-- Nadie puede leer ni escribir la tabla directamente desde la web.
alter table public.cuestionarios enable row level security;
revoke all on public.cuestionarios from anon, authenticated;

-- La web solo puede guardar su propio cuestionario a través de esta función.
create or replace function public.guardar_cuestionario(
  p_id uuid, p_proyecto text, p_respuestas jsonb, p_texto text, p_estado text
) returns void
language plpgsql security definer set search_path = public as $$
begin
  if p_estado not in ('borrador','enviado') then raise exception 'estado no válido'; end if;
  if pg_column_size(p_respuestas) > 300000 or length(coalesce(p_texto,'')) > 300000 then
    raise exception 'demasiado grande';
  end if;
  insert into cuestionarios (id, proyecto, respuestas, texto, estado, enviado)
  values (p_id, left(p_proyecto,100), p_respuestas, p_texto, p_estado,
          case when p_estado = 'enviado' then now() end)
  on conflict (id) do update set
    respuestas  = excluded.respuestas,
    texto       = excluded.texto,
    estado      = case when cuestionarios.estado = 'enviado' then 'enviado' else excluded.estado end,
    enviado     = coalesce(cuestionarios.enviado, excluded.enviado),
    actualizado = now();
end $$;

-- Para seguir rellenando desde otro dispositivo con el mismo enlace (?id=...).
create or replace function public.cargar_cuestionario(p_id uuid)
returns jsonb
language sql security definer set search_path = public as $$
  select respuestas from cuestionarios where id = p_id;
$$;

revoke all on function public.guardar_cuestionario(uuid,text,jsonb,text,text) from public;
revoke all on function public.cargar_cuestionario(uuid) from public;
grant execute on function public.guardar_cuestionario(uuid,text,jsonb,text,text) to anon;
grant execute on function public.cargar_cuestionario(uuid) to anon;

-- Para ver las respuestas (desde el SQL Editor):
-- select proyecto, estado, actualizado, enviado, texto from cuestionarios order by actualizado desc;
