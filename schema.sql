# MySQL Schema for Gram Nirikshan App
# Run this SQL to initialize the database

CREATE DATABASE IF NOT EXISTS gram_nirikshan CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci;
USE gram_nirikshan;

-- ─────────────────────────────────────────────────────────────────
-- USERS TABLE
-- ─────────────────────────────────────────────────────────────────
CREATE TABLE IF NOT EXISTS users (
    id VARCHAR(36) PRIMARY KEY DEFAULT (UUID()),
    mobile VARCHAR(15) NOT NULL UNIQUE,
    hashed_password VARCHAR(255) NULL,
    name VARCHAR(100) NOT NULL,
    name_hindi VARCHAR(200),
    email VARCHAR(100) UNIQUE,
    role ENUM('superadmin','admin','je','ae','xen','viewer') NOT NULL DEFAULT 'je',
    employee_id VARCHAR(50) UNIQUE,
    designation VARCHAR(100),
    department VARCHAR(100),
    district VARCHAR(100),
    block VARCHAR(100),
    profile_photo VARCHAR(255),
    is_active BOOLEAN DEFAULT TRUE,
    firebase_token VARCHAR(255),
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
    INDEX idx_mobile (mobile),
    INDEX idx_role (role),
    INDEX idx_district (district)
) ENGINE=InnoDB;

-- ─────────────────────────────────────────────────────────────────
-- OTP RECORDS TABLE
-- ─────────────────────────────────────────────────────────────────
CREATE TABLE IF NOT EXISTS otp_records (
    id INT AUTO_INCREMENT PRIMARY KEY,
    mobile VARCHAR(15) NOT NULL,
    otp VARCHAR(10) NOT NULL,
    is_used BOOLEAN DEFAULT FALSE,
    expires_at TIMESTAMP NOT NULL,
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    INDEX idx_mobile (mobile),
    INDEX idx_expires (expires_at)
) ENGINE=InnoDB;

-- ─────────────────────────────────────────────────────────────────
-- PANCHAYATS TABLE
-- ─────────────────────────────────────────────────────────────────
CREATE TABLE IF NOT EXISTS panchayats (
    id VARCHAR(36) PRIMARY KEY DEFAULT (UUID()),
    name VARCHAR(200) NOT NULL,
    name_hindi VARCHAR(300),
    code VARCHAR(20) UNIQUE,
    district VARCHAR(100) NOT NULL,
    block VARCHAR(100) NOT NULL,
    village VARCHAR(200),
    population INT,
    latitude DECIMAL(10, 8),
    longitude DECIMAL(11, 8),
    sarpanch_name VARCHAR(100),
    sarpanch_mobile VARCHAR(15),
    is_active BOOLEAN DEFAULT TRUE,
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
    INDEX idx_district (district),
    INDEX idx_block (block)
) ENGINE=InnoDB;

-- ─────────────────────────────────────────────────────────────────
-- INSPECTIONS TABLE
-- ─────────────────────────────────────────────────────────────────
CREATE TABLE IF NOT EXISTS inspections (
    id VARCHAR(36) PRIMARY KEY DEFAULT (UUID()),
    inspection_id VARCHAR(30) NOT NULL UNIQUE,  -- Auto-generated: GN-YYYYMM-XXXXX
    panchayat_id VARCHAR(36) NOT NULL,
    engineer_id VARCHAR(36) NOT NULL,
    status ENUM('draft','submitted','forwarded','approved','rejected') NOT NULL DEFAULT 'draft',
    title VARCHAR(300) NOT NULL,
    description TEXT,
    inspection_type VARCHAR(100),
    project_name VARCHAR(300),
    project_code VARCHAR(50),
    -- GPS Data
    checkin_latitude DECIMAL(10, 8),
    checkin_longitude DECIMAL(11, 8),
    checkin_time TIMESTAMP,
    checkin_address VARCHAR(500),
    checkout_latitude DECIMAL(10, 8),
    checkout_longitude DECIMAL(11, 8),
    checkout_time TIMESTAMP,
    checkout_address VARCHAR(500),
    distance_covered_km DECIMAL(8, 3),
    -- Inspection Content
    observations TEXT,
    recommendations TEXT,
    action_taken TEXT,
    -- AI Content
    ai_report_draft TEXT,
    ai_suggestions JSON,
    -- Timestamps
    inspection_date TIMESTAMP,
    submitted_at TIMESTAMP,
    approved_at TIMESTAMP,
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
    -- Foreign Keys
    FOREIGN KEY (panchayat_id) REFERENCES panchayats(id) ON DELETE RESTRICT,
    FOREIGN KEY (engineer_id) REFERENCES users(id) ON DELETE RESTRICT,
    -- Indexes
    INDEX idx_status (status),
    INDEX idx_engineer (engineer_id),
    INDEX idx_panchayat (panchayat_id),
    INDEX idx_inspection_id (inspection_id),
    INDEX idx_created (created_at)
) ENGINE=InnoDB;

-- ─────────────────────────────────────────────────────────────────
-- PHOTOS TABLE
-- ─────────────────────────────────────────────────────────────────
CREATE TABLE IF NOT EXISTS photos (
    id VARCHAR(36) PRIMARY KEY DEFAULT (UUID()),
    inspection_id VARCHAR(36) NOT NULL,
    file_path VARCHAR(500) NOT NULL,
    thumbnail_path VARCHAR(500),
    original_filename VARCHAR(255),
    file_size_kb INT,
    mime_type VARCHAR(50),
    latitude DECIMAL(10, 8),
    longitude DECIMAL(11, 8),
    captured_at TIMESTAMP,
    engineer_name VARCHAR(100),
    panchayat_name VARCHAR(200),
    address VARCHAR(500),
    caption VARCHAR(500),
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    FOREIGN KEY (inspection_id) REFERENCES inspections(id) ON DELETE CASCADE,
    INDEX idx_inspection (inspection_id)
) ENGINE=InnoDB;

-- ─────────────────────────────────────────────────────────────────
-- DOCUMENTS TABLE
-- ─────────────────────────────────────────────────────────────────
CREATE TABLE IF NOT EXISTS documents (
    id VARCHAR(36) PRIMARY KEY DEFAULT (UUID()),
    inspection_id VARCHAR(36),
    uploaded_by VARCHAR(36) NOT NULL,
    document_type ENUM('pdf','image','excel','other') NOT NULL,
    file_path VARCHAR(500) NOT NULL,
    original_filename VARCHAR(255) NOT NULL,
    file_size_kb INT,
    mime_type VARCHAR(100),
    description VARCHAR(500),
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    FOREIGN KEY (inspection_id) REFERENCES inspections(id) ON DELETE SET NULL,
    FOREIGN KEY (uploaded_by) REFERENCES users(id),
    INDEX idx_inspection (inspection_id),
    INDEX idx_uploaded_by (uploaded_by)
) ENGINE=InnoDB;

-- ─────────────────────────────────────────────────────────────────
-- REPORTS TABLE
-- ─────────────────────────────────────────────────────────────────
CREATE TABLE IF NOT EXISTS reports (
    id VARCHAR(36) PRIMARY KEY DEFAULT (UUID()),
    inspection_id VARCHAR(36) NOT NULL,
    generated_by VARCHAR(36) NOT NULL,
    file_path VARCHAR(500) NOT NULL,
    file_name VARCHAR(255) NOT NULL,
    file_size_kb INT,
    report_format VARCHAR(20) DEFAULT 'pdf',
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    FOREIGN KEY (inspection_id) REFERENCES inspections(id) ON DELETE CASCADE,
    FOREIGN KEY (generated_by) REFERENCES users(id),
    INDEX idx_inspection (inspection_id)
) ENGINE=InnoDB;

-- ─────────────────────────────────────────────────────────────────
-- APPROVALS TABLE
-- ─────────────────────────────────────────────────────────────────
CREATE TABLE IF NOT EXISTS approvals (
    id VARCHAR(36) PRIMARY KEY DEFAULT (UUID()),
    inspection_id VARCHAR(36) NOT NULL,
    approver_id VARCHAR(36) NOT NULL,
    level VARCHAR(10) NOT NULL,     -- JE, AE, XEN, ADMIN
    action ENUM('pending','approved','rejected','forwarded') DEFAULT 'pending',
    remarks TEXT,
    forward_to VARCHAR(36),
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
    FOREIGN KEY (inspection_id) REFERENCES inspections(id) ON DELETE CASCADE,
    FOREIGN KEY (approver_id) REFERENCES users(id),
    FOREIGN KEY (forward_to) REFERENCES users(id),
    INDEX idx_inspection (inspection_id),
    INDEX idx_approver (approver_id),
    INDEX idx_action (action)
) ENGINE=InnoDB;

-- ─────────────────────────────────────────────────────────────────
-- FORWARDING HISTORY TABLE
-- ─────────────────────────────────────────────────────────────────
CREATE TABLE IF NOT EXISTS forwarding_history (
    id VARCHAR(36) PRIMARY KEY DEFAULT (UUID()),
    inspection_id VARCHAR(36) NOT NULL,
    forwarded_by VARCHAR(36) NOT NULL,
    recipient_designation VARCHAR(100) NOT NULL,
    recipient_contact VARCHAR(100) NOT NULL,
    remarks TEXT,
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    FOREIGN KEY (inspection_id) REFERENCES inspections(id) ON DELETE CASCADE,
    FOREIGN KEY (forwarded_by) REFERENCES users(id),
    INDEX idx_inspection (inspection_id)
) ENGINE=InnoDB;

-- ─────────────────────────────────────────────────────────────────
-- NOTIFICATIONS TABLE
-- ─────────────────────────────────────────────────────────────────
CREATE TABLE IF NOT EXISTS notifications (
    id VARCHAR(36) PRIMARY KEY DEFAULT (UUID()),
    user_id VARCHAR(36) NOT NULL,
    title VARCHAR(200) NOT NULL,
    body TEXT,
    notification_type ENUM(
        'inspection_submitted','inspection_approved','inspection_rejected',
        'inspection_forwarded','reminder','system'
    ) NOT NULL,
    reference_id VARCHAR(36),
    is_read BOOLEAN DEFAULT FALSE,
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    FOREIGN KEY (user_id) REFERENCES users(id) ON DELETE CASCADE,
    INDEX idx_user (user_id),
    INDEX idx_is_read (is_read),
    INDEX idx_created (created_at)
) ENGINE=InnoDB;

-- ─────────────────────────────────────────────────────────────────
-- SEED DATA: Default Admin User
-- ─────────────────────────────────────────────────────────────────
INSERT IGNORE INTO users (id, mobile, name, name_hindi, email, role, employee_id, designation, is_active)
VALUES (
    UUID(),
    '9999999999',
    'System Administrator',
    'सिस्टम प्रशासक',
    'admin@gramnirikshan.in',
    'admin',
    'ADMIN001',
    'System Admin',
    TRUE
);

-- Sample Panchayat
INSERT IGNORE INTO panchayats (id, name, name_hindi, code, district, block, village, latitude, longitude)
VALUES (
    UUID(),
    'Rampur Gram Panchayat',
    'रामपुर ग्राम पंचायत',
    'GP001',
    'Lucknow',
    'Mohanlalganj',
    'Rampur',
    26.8467,
    80.9462
);
