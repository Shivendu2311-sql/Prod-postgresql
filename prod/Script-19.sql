explain analyze
select * from public.get_lead_counts_nds_2('005WG00000A4lQnYAJ',
'2025-01-20','2025-01-20','{}','all')


select * from public.get_agent_and_team_counts('005WG00000A4lQnYAJ',
'2025-01-20','2025-01-20','{}','all', array['a0520bbe-05ae-42a7-83fd-1e1c47369af4'])

select * from public.get_agent_and_team_counts('005WG00000A4lQnYAJ',
'2025-01-20','2025-01-20','{}','all')

-- DROP FUNCTION public.get_agent_and_team_counts(text, date, date, _text, text, _varchar);

