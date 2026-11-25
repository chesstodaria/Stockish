-- 0006_seed_data.sql
-- Data awal dari `stockisi/lib/data/mock_seed.dart`, supaya demo di Supabase
-- terasa sama dengan demo di mock.
--
-- Saldo akhir dihitung dari riwayat: RCV menambah, INT mengurangi. Jadi
-- angka di `stocks` konsisten dengan `transactions` dan `transaction_items`,
-- bukan angka yang ditempel.

insert into public.items (code, name, uom, warehouse_code, rack_number) values
  ('BRG-0001','Plat Besi SPCC 1,2 mm 4x8 ft','LBR','WH01','A-01-01'),
  ('BRG-0002','Baut Hex M10x30 Galvanis','PCS','WH01','A-02-03'),
  ('BRG-0003','Mur Hex M10 Galvanis','PCS','WH01','A-02-04'),
  ('BRG-0004','Cat Dasar Epoxy Abu-abu 20 L','PAIL','WH01','C-01-02'),
  ('BRG-0005','Thinner Epoxy 5 L','KLG','WH01','C-01-03'),
  ('BRG-0006','Kawat Las ER70S-6 0,8 mm 15 kg','ROL','WH01','B-03-01'),
  ('BRG-0007','Gas Argon Silinder 6 m3','TBG','WH01','D-01-01'),
  ('BRG-0008','Kardus Double Wall 60x40x40 cm','PCS','WH01','E-02-01'),
  ('BRG-0009','Stretch Film 50 cm x 300 m','ROL','WH01','E-02-03'),
  ('BRG-0010','Pipa Hollow 40x40x2 mm 6 m','BTG','WH01','A-01-04'),
  ('BRG-0011','Sarung Tangan Katun Bintik','PSG','WH01','F-01-02'),
  ('BRG-0012','Bearing 6205-2RS','PCS','WH01','B-01-05'),
  ('BRG-0013','Palet Kayu 120x100 cm','PCS','WH01','E-01-01'),
  ('BRG-0014','Mata Gerinda Potong 4 inci','PCS','WH01','B-02-02'),
  ('BRG-0015','Resin Polypropylene Homopolimer 25 kg','SAK','WH01','C-02-01'),
  ('BRG-0101','Rak Besi Siku 5 Susun','UNIT','WH02','R-01-01'),
  ('BRG-0102','Kabinet Panel Listrik 40x30 cm','UNIT','WH02','R-01-02'),
  ('BRG-0103','Kardus Single Wall 40x30x30 cm','PCS','WH02','R-02-01'),
  ('BRG-0104','Lakban Coklat 2 inci','ROL','WH02','R-02-02')
on conflict (code) do nothing;

insert into public.stocks (item_code, warehouse_code, quantity)
select i.code, i.warehouse_code, v.qty
from (values
  ('BRG-0001',200),('BRG-0002',3000),('BRG-0003',3000),('BRG-0004',40),
  ('BRG-0005',60),('BRG-0006',50),('BRG-0007',20),('BRG-0008',900),
  ('BRG-0009',80),('BRG-0010',150),('BRG-0011',400),('BRG-0012',100),
  ('BRG-0013',60),('BRG-0014',120),('BRG-0015',200),
  ('BRG-0101',30),('BRG-0102',25),('BRG-0103',1500),('BRG-0104',100)
) as v(code, qty)
join public.items i on i.code = v.code
on conflict (item_code, warehouse_code) do update set quantity = excluded.quantity;

insert into public.reference_documents
  (number, type, warehouse_code, counterparty, document_date, status, version)
values
  ('PO-2610-0031','RCV','WH01','PT Baja Prima Sentosa','2026-10-05','SUBMITTED',1),
  ('PO-2610-0034','RCV','WH01','CV Sumber Teknik Abadi','2026-10-12','SUBMITTED',1),
  ('BON-2610-0019','INT','WH01','Lini Produksi 1 - Fabrikasi Rangka','2026-10-28','SUBMITTED',1),
  ('PO-2611-0041','RCV','WH01','PT Baja Prima Sentosa','2026-11-19','OPEN',0),
  ('PO-2611-0043','RCV','WH01','PT Mitra Logistik Supply','2026-11-18','OPEN',1),
  ('PO-2611-0046','RCV','WH01','CV Sumber Teknik Abadi','2026-11-20','OPEN',0),
  ('PO-2611-0048','RCV','WH01','PT Sinar Industri Supply','2026-11-21','OPEN',0),
  ('BON-2611-0012','INT','WH01','Lini Produksi 1 - Fabrikasi Rangka','2026-11-18','OPEN',1),
  ('BON-2611-0014','INT','WH01','Lini Produksi 1 - Fabrikasi Rangka','2026-11-20','OPEN',0),
  ('BON-2611-0016','INT','WH01','Lini Produksi 2 - Pengecatan','2026-11-21','OPEN',0),
  ('PO-2611-0049','RCV','WH02','PT Sinar Industri Supply','2026-11-12','SUBMITTED',1),
  ('PO-2611-0052','RCV','WH02','PT Baja Prima Sentosa','2026-11-20','OPEN',0)
on conflict (number) do nothing;

insert into public.reference_document_items
  (document_number, item_code, ordered_quantity, processed_quantity, status)
select v.doc, v.code, v.ordered, v.processed,
       case when v.processed >= v.ordered then 'COMPLETE'::public.item_status
            when v.processed > 0 then 'PARTIAL'::public.item_status
            else 'PENDING'::public.item_status end
from (values
  ('PO-2610-0031','BRG-0001',120,120),('PO-2610-0031','BRG-0010',80,80),
  ('PO-2610-0031','BRG-0006',30,30),('PO-2610-0031','BRG-0007',12,12),
  ('PO-2610-0034','BRG-0002',2000,2000),('PO-2610-0034','BRG-0003',2000,2000),
  ('PO-2610-0034','BRG-0011',300,300),('PO-2610-0034','BRG-0012',60,60),
  ('BON-2610-0019','BRG-0001',40,40),('BON-2610-0019','BRG-0010',30,30),
  ('BON-2610-0019','BRG-0006',8,8),('BON-2610-0019','BRG-0007',8,8),
  ('PO-2611-0041','BRG-0001',60,0),('PO-2611-0041','BRG-0010',40,0),
  ('PO-2611-0041','BRG-0014',100,0),('PO-2611-0041','BRG-0006',20,0),
  ('PO-2611-0043','BRG-0008',400,400),('PO-2611-0043','BRG-0009',30,30),
  ('PO-2611-0043','BRG-0013',40,40),('PO-2611-0043','BRG-0015',100,40),
  ('PO-2611-0043','BRG-0012',24,0),
  ('PO-2611-0046','BRG-0002',100,0),('PO-2611-0046','BRG-0003',100,0),
  ('PO-2611-0046','BRG-0012',20,0),
  ('PO-2611-0048','BRG-0004',12,0),('PO-2611-0048','BRG-0005',20,0),
  ('PO-2611-0048','BRG-0015',80,0),
  ('BON-2611-0012','BRG-0012',20,12),('BON-2611-0012','BRG-0002',500,500),
  ('BON-2611-0012','BRG-0003',500,0),('BON-2611-0012','BRG-0008',100,0),
  ('BON-2611-0014','BRG-0001',20,0),('BON-2611-0014','BRG-0010',20,0),
  ('BON-2611-0014','BRG-0006',10,0),('BON-2611-0014','BRG-0011',30,0),
  ('BON-2611-0016','BRG-0004',6,0),('BON-2611-0016','BRG-0005',10,0),
  ('BON-2611-0016','BRG-0007',10,0),('BON-2611-0016','BRG-0011',40,0),
  ('PO-2611-0049','BRG-0101',20,20),('PO-2611-0049','BRG-0102',15,15),
  ('PO-2611-0049','BRG-0103',1000,1000),
  ('PO-2611-0052','BRG-0103',100,0),('PO-2611-0052','BRG-0104',20,0)
) as v(doc, code, ordered, processed)
on conflict (document_number, item_code) do nothing;

insert into public.transactions
  (number, document_number, type, warehouse_code, operator_id,
   submitted_at, vendor_delivery_no, closed_document)
values
  ('TRX-RCV-261007-0001','PO-2610-0031','RCV','WH01',
   '11111111-1111-1111-1111-111111111111','2026-10-07 08:40+07','SJ/BPS/10/0457',true),
  ('TRX-RCV-261014-0002','PO-2610-0034','RCV','WH01',
   '22222222-2222-2222-2222-222222222222','2026-10-14 10:15+07','SJ-STA-2610-118',true),
  ('TRX-INT-261028-0003','BON-2610-0019','INT','WH01',
   '22222222-2222-2222-2222-222222222222','2026-10-28 09:30+07',null,true),
  ('TRX-RCV-261118-0004','PO-2611-0043','RCV','WH01',
   '22222222-2222-2222-2222-222222222222','2026-11-18 09:10+07','SJ/MLS/11/2231',false),
  ('TRX-INT-261119-0005','BON-2611-0012','INT','WH01',
   '22222222-2222-2222-2222-222222222222','2026-11-19 15:45+07',null,false),
  ('TRX-RCV-261112-0006','PO-2611-0049','RCV','WH02',
   '44444444-4444-4444-4444-444444444444','2026-11-12 10:00+07','SJ/SIS/11/0788',true)
on conflict (number) do nothing;

insert into public.transaction_items
  (transaction_number, item_code, item_name, uom, rack_number, quantity, marked_unavailable)
select v.trx, i.code, i.name, i.uom, i.rack_number, v.qty, false
from (values
  ('TRX-RCV-261007-0001','BRG-0001',120),('TRX-RCV-261007-0001','BRG-0010',80),
  ('TRX-RCV-261007-0001','BRG-0006',30),('TRX-RCV-261007-0001','BRG-0007',12),
  ('TRX-RCV-261014-0002','BRG-0002',2000),('TRX-RCV-261014-0002','BRG-0003',2000),
  ('TRX-RCV-261014-0002','BRG-0011',300),('TRX-RCV-261014-0002','BRG-0012',60),
  ('TRX-INT-261028-0003','BRG-0001',40),('TRX-INT-261028-0003','BRG-0010',30),
  ('TRX-INT-261028-0003','BRG-0006',8),('TRX-INT-261028-0003','BRG-0007',8),
  ('TRX-RCV-261118-0004','BRG-0008',400),('TRX-RCV-261118-0004','BRG-0009',30),
  ('TRX-RCV-261118-0004','BRG-0013',40),('TRX-RCV-261118-0004','BRG-0015',40),
  ('TRX-INT-261119-0005','BRG-0012',12),('TRX-INT-261119-0005','BRG-0002',500),
  ('TRX-RCV-261112-0006','BRG-0101',20),('TRX-RCV-261112-0006','BRG-0102',15),
  ('TRX-RCV-261112-0006','BRG-0103',1000)
) as v(trx, code, qty)
join public.items i on i.code = v.code
on conflict (transaction_number, item_code) do nothing;

-- Saldo akhir mengikuti riwayat: RCV menambah, INT mengurangi.
update public.stocks s set quantity = s.quantity
  + coalesce((select sum(ti.quantity) from public.transaction_items ti
               join public.transactions t on t.number = ti.transaction_number
              where t.type = 'RCV' and ti.item_code = s.item_code
                and t.warehouse_code = s.warehouse_code), 0)
  - coalesce((select sum(ti.quantity) from public.transaction_items ti
               join public.transactions t on t.number = ti.transaction_number
              where t.type = 'INT' and ti.item_code = s.item_code
                and t.warehouse_code = s.warehouse_code), 0);
