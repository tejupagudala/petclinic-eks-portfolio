INSERT IGNORE INTO vets (id, first_name, last_name) VALUES (1, 'James', 'Carter');
INSERT IGNORE INTO vets (id, first_name, last_name) VALUES (2, 'Helen', 'Leary');
INSERT IGNORE INTO vets (id, first_name, last_name) VALUES (3, 'Linda', 'Douglas');
INSERT IGNORE INTO vets (id, first_name, last_name) VALUES (4, 'Rafael', 'Ortega');
INSERT IGNORE INTO vets (id, first_name, last_name) VALUES (5, 'Henry', 'Stevens');
INSERT IGNORE INTO vets (id, first_name, last_name) VALUES (6, 'Sharon', 'Jenkins');

INSERT IGNORE INTO specialties (id, name) VALUES (1, 'radiology');
INSERT IGNORE INTO specialties (id, name) VALUES (2, 'surgery');
INSERT IGNORE INTO specialties (id, name) VALUES (3, 'dentistry');

INSERT IGNORE INTO vet_specialties (vet_id, specialty_id) VALUES (2, 1);
INSERT IGNORE INTO vet_specialties (vet_id, specialty_id) VALUES (3, 2);
INSERT IGNORE INTO vet_specialties (vet_id, specialty_id) VALUES (3, 3);
INSERT IGNORE INTO vet_specialties (vet_id, specialty_id) VALUES (4, 2);
INSERT IGNORE INTO vet_specialties (vet_id, specialty_id) VALUES (5, 1);
