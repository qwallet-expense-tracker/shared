select *
from list_accounts_for_user('18461394991059970');

select update_account_for_user('QW-AC-0000000369620046', '18461394991059970', 'Eganow');

select *
from list_beneficiaries_for_user('18461394991059970', 1, 10);

select *
from list_categories_for_user('18461394991059970');

select *
from list_transactions_for_user_by_account('18461394991059970', 'QW-AC-0000000369620046',
                                           '2024-01-01 00:00:00 +00:00',
                                           '2024-04-25 23:59:59 +00:00', 1, 10);

select *
from list_transactions_for_user('18461394991059970',
                                           '2024-01-01 00:00:00 +0000',
                                           '2024-04-25 23:59:59 +0000', 1, 5);

select *
from list_transactions_for_user_by_type('18461394991059970', 'CREDIT',
                                        '2024-01-01 00:00:00 +00:00',
                                        '2024-04-07 21:00:00 +00:00', 1, 10);

select *
from get_user_stats('quabynahdennis@gmail.com');
