// ===============================================
// BACKEND REGISTRATION CONTROLLER
// File: super-admin-backend/controllers/mobileAuthController.js
// ===============================================
// This controller handles mobile app registration
// CRITICAL: Must handle zipcodes as TEXT[] array
// ===============================================

const bcrypt = require('bcrypt');
const jwt = require('jsonwebtoken');
const { createClient } = require('@supabase/supabase-js');

// Initialize Supabase client
const supabase = createClient(
  process.env.SUPABASE_URL,
  process.env.SUPABASE_SERVICE_KEY
);

/**
 * Register a new agency from mobile app
 * POST /api/mobile/auth/register
 * 
 * Request Body:
 * {
 *   email: string,
 *   password: string,
 *   agency_name: string,
 *   business_name: string,
 *   contact_name: string,
 *   phone: string,
 *   industry: string,
 *   plan_id: string,
 *   payment_method_id: string,
 *   zipcodes: string[]  // ARRAY OF STRINGS (e.g., ["75001", "75002"])
 * }
 */
async function register(req, res) {
  console.log('📝 Mobile Registration Request:', {
    email: req.body.email,
    agency_name: req.body.agency_name,
    zipcodes_count: req.body.zipcodes?.length || 0,
    zipcodes_type: Array.isArray(req.body.zipcodes) ? 'array' : typeof req.body.zipcodes
  });

  try {
    const {
      email,
      password,
      agency_name,
      business_name,
      contact_name,
      phone,
      industry,
      plan_id,
      payment_method_id,
      zipcodes  // CRITICAL: This comes as an array from mobile app
    } = req.body;

    // ===== VALIDATION =====
    
    // Required fields
    if (!email || !password || !agency_name) {
      return res.status(400).json({
        success: false,
        message: 'Missing required fields',
        error: 'email, password, and agency_name are required'
      });
    }

    // Validate email format
    const emailRegex = /^[^\s@]+@[^\s@]+\.[^\s@]+$/;
    if (!emailRegex.test(email)) {
      return res.status(400).json({
        success: false,
        message: 'Invalid email format'
      });
    }

    // ===== ZIPCODES VALIDATION =====
    
    // CRITICAL: Zipcodes must be an array
    let zipcodesArray = [];
    
    if (zipcodes) {
      if (Array.isArray(zipcodes)) {
        // Validate each zipcode is a 5-digit string
        zipcodesArray = zipcodes
          .filter(zip => typeof zip === 'string' && /^\d{5}$/.test(zip))
          .map(zip => zip.trim());
        
        console.log('✅ Zipcodes validated:', {
          received: zipcodes.length,
          valid: zipcodesArray.length,
          sample: zipcodesArray.slice(0, 3)
        });
      } else if (typeof zipcodes === 'string') {
        // Handle case where zipcodes is sent as string (shouldn't happen with mobile app)
        console.warn('⚠️ Zipcodes received as string, converting to array');
        const parsed = zipcodes.split(',').map(z => z.trim());
        zipcodesArray = parsed.filter(zip => /^\d{5}$/.test(zip));
      } else {
        console.error('❌ Invalid zipcodes format:', typeof zipcodes);
        return res.status(400).json({
          success: false,
          message: 'Invalid zipcodes format',
          error: 'Zipcodes must be an array of 5-digit strings'
        });
      }
    }

    // ===== INDUSTRY VALIDATION =====
    
    const validIndustries = [
      'Home Health and Hospice',
      'Insurance',
      'Finance',
      'Handyman Services',
      'Healthcare'  // Legacy/default
    ];
    
    const industryValue = industry && validIndustries.includes(industry)
      ? industry
      : 'Healthcare';  // Default fallback
    
    if (industry && !validIndustries.includes(industry)) {
      console.warn(`⚠️ Invalid industry "${industry}", using default "Healthcare"`);
    }

    // ===== PASSWORD HASHING =====
    
    const saltRounds = 10;
    const hashedPassword = await bcrypt.hash(password, saltRounds);
    
    console.log('✅ Password hashed successfully');

    // ===== DATABASE INSERT =====
    
    console.log('💾 Inserting into database:', {
      email,
      agency_name,
      business_name,
      contact_name,
      phone,
      industry: industryValue,
      plan_id,
      payment_method_id,
      zipcodes: zipcodesArray,
      zipcodes_type: 'TEXT[] array',
      zipcodes_count: zipcodesArray.length
    });

    const { data, error } = await supabase
      .from('agencies')
      .insert({
        email: email.toLowerCase().trim(),
        password: hashedPassword,
        agency_name: agency_name.trim(),
        business_name: business_name ? business_name.trim() : agency_name.trim(),
        contact_name: contact_name ? contact_name.trim() : null,
        phone: phone ? phone.trim() : null,
        industry: industryValue,
        plan_id: plan_id || null,
        payment_method_id: payment_method_id || null,
        zipcodes: zipcodesArray,  // CRITICAL: Pass as array, Supabase handles TEXT[] conversion
        territory_count: zipcodesArray.length,
        territory_limit: 0,  // Will be set based on plan
        is_active: true,
        is_verified: false,
        created_at: new Date().toISOString(),
        updated_at: new Date().toISOString()
      })
      .select();

    if (error) {
      console.error('❌ Database insert error:', {
        message: error.message,
        details: error.details,
        hint: error.hint,
        code: error.code
      });

      // Handle duplicate email
      if (error.code === '23505') {  // PostgreSQL unique violation
        return res.status(409).json({
          success: false,
          message: 'Email already registered',
          error: 'An account with this email already exists'
        });
      }

      return res.status(500).json({
        success: false,
        message: 'Failed to create agency',
        error: error.message,
        details: error.details
      });
    }

    if (!data || data.length === 0) {
      console.error('❌ No data returned from insert');
      return res.status(500).json({
        success: false,
        message: 'Failed to create agency',
        error: 'No data returned from database'
      });
    }

    const agency = data[0];
    console.log('✅ Agency created successfully:', {
      id: agency.id,
      email: agency.email,
      zipcodes_saved: agency.zipcodes
    });

    // ===== JWT TOKEN GENERATION =====
    
    const jwtSecret = process.env.JWT_SECRET;
    if (!jwtSecret) {
      console.error('❌ JWT_SECRET not configured');
      return res.status(500).json({
        success: false,
        message: 'Server configuration error',
        error: 'JWT secret not configured'
      });
    }

    const tokenPayload = {
      agency_id: agency.id,
      email: agency.email,
      type: 'mobile'
    };

    const token = jwt.sign(tokenPayload, jwtSecret, {
      expiresIn: '30d'  // 30 days expiration
    });

    console.log('✅ JWT token generated');

    // ===== SUCCESS RESPONSE =====
    
    return res.status(201).json({
      success: true,
      message: 'Agency registered successfully',
      token: token,
      agency_id: agency.id,
      user_profile: {
        id: agency.id,
        email: agency.email,
        agency_name: agency.agency_name,
        business_name: agency.business_name,
        contact_name: agency.contact_name,
        phone: agency.phone,
        industry: agency.industry,
        zipcodes: agency.zipcodes,  // Return zipcodes array
        territory_count: agency.territory_count,
        is_verified: agency.is_verified
      }
    });

  } catch (err) {
    console.error('❌ Registration error:', {
      message: err.message,
      stack: err.stack
    });

    return res.status(500).json({
      success: false,
      message: 'Internal server error',
      error: err.message
    });
  }
}

/**
 * Get agency territories (zipcodes)
 * GET /api/mobile/territories
 * Requires JWT authentication
 */
async function getTerritories(req, res) {
  try {
    const agencyId = req.agency_id;  // From JWT middleware

    console.log('📍 Fetching territories for agency:', agencyId);

    const { data, error } = await supabase
      .from('agencies')
      .select('zipcodes, territory_count, territory_limit')
      .eq('id', agencyId)
      .single();

    if (error) {
      console.error('❌ Database error:', error);
      return res.status(500).json({
        success: false,
        message: 'Failed to fetch territories',
        error: error.message
      });
    }

    if (!data) {
      return res.status(404).json({
        success: false,
        message: 'Agency not found'
      });
    }

    // Ensure zipcodes is an array
    const zipcodes = Array.isArray(data.zipcodes) ? data.zipcodes : [];

    console.log('✅ Territories fetched:', {
      count: zipcodes.length,
      limit: data.territory_limit
    });

    return res.status(200).json({
      success: true,
      zipcodes: zipcodes,
      territory_count: data.territory_count || zipcodes.length,
      territory_limit: data.territory_limit || 0
    });

  } catch (err) {
    console.error('❌ Get territories error:', err);
    return res.status(500).json({
      success: false,
      message: 'Internal server error',
      error: err.message
    });
  }
}

/**
 * Add zipcode territory
 * POST /api/mobile/territories
 * Requires JWT authentication
 */
async function addTerritory(req, res) {
  try {
    const agencyId = req.agency_id;  // From JWT middleware
    const { zipcode, city } = req.body;

    if (!zipcode || !/^\d{5}$/.test(zipcode)) {
      return res.status(400).json({
        success: false,
        message: 'Invalid zipcode format',
        error: 'Zipcode must be a 5-digit number'
      });
    }

    console.log('📍 Adding territory:', { agencyId, zipcode, city });

    // Get current zipcodes and limits
    const { data: agency, error: fetchError } = await supabase
      .from('agencies')
      .select('zipcodes, territory_limit')
      .eq('id', agencyId)
      .single();

    if (fetchError) {
      console.error('❌ Database error:', fetchError);
      return res.status(500).json({
        success: false,
        message: 'Failed to fetch agency data',
        error: fetchError.message
      });
    }

    const currentZipcodes = Array.isArray(agency.zipcodes) ? agency.zipcodes : [];

    // Check if zipcode already exists
    if (currentZipcodes.includes(zipcode)) {
      return res.status(409).json({
        success: false,
        message: 'Zipcode already exists',
        error: 'This zipcode is already in your territories'
      });
    }

    // Check territory limit
    if (agency.territory_limit > 0 && currentZipcodes.length >= agency.territory_limit) {
      return res.status(403).json({
        success: false,
        message: 'Territory limit reached',
        error: `You can only have ${agency.territory_limit} territories. Upgrade your plan for more.`
      });
    }

    // Add zipcode to array
    const updatedZipcodes = [...currentZipcodes, zipcode];

    // Update database
    const { data, error } = await supabase
      .from('agencies')
      .update({
        zipcodes: updatedZipcodes,
        territory_count: updatedZipcodes.length,
        updated_at: new Date().toISOString()
      })
      .eq('id', agencyId)
      .select('zipcodes, territory_count');

    if (error) {
      console.error('❌ Database error:', error);
      return res.status(500).json({
        success: false,
        message: 'Failed to add territory',
        error: error.message
      });
    }

    console.log('✅ Territory added successfully');

    return res.status(201).json({
      success: true,
      message: 'Territory added successfully',
      zipcodes: data[0].zipcodes,
      territory_count: data[0].territory_count
    });

  } catch (err) {
    console.error('❌ Add territory error:', err);
    return res.status(500).json({
      success: false,
      message: 'Internal server error',
      error: err.message
    });
  }
}

/**
 * Remove zipcode territory
 * DELETE /api/mobile/territories/:territoryId
 * Requires JWT authentication
 */
async function removeTerritory(req, res) {
  try {
    const agencyId = req.agency_id;  // From JWT middleware
    const { territoryId } = req.params;  // Can be zipcode or id

    console.log('📍 Removing territory:', { agencyId, territoryId });

    // Get current zipcodes
    const { data: agency, error: fetchError } = await supabase
      .from('agencies')
      .select('zipcodes')
      .eq('id', agencyId)
      .single();

    if (fetchError) {
      console.error('❌ Database error:', fetchError);
      return res.status(500).json({
        success: false,
        message: 'Failed to fetch agency data',
        error: fetchError.message
      });
    }

    const currentZipcodes = Array.isArray(agency.zipcodes) ? agency.zipcodes : [];

    // Remove zipcode from array
    const updatedZipcodes = currentZipcodes.filter(zip => zip !== territoryId);

    if (currentZipcodes.length === updatedZipcodes.length) {
      return res.status(404).json({
        success: false,
        message: 'Territory not found',
        error: 'This zipcode is not in your territories'
      });
    }

    // Update database
    const { data, error } = await supabase
      .from('agencies')
      .update({
        zipcodes: updatedZipcodes,
        territory_count: updatedZipcodes.length,
        updated_at: new Date().toISOString()
      })
      .eq('id', agencyId)
      .select('zipcodes, territory_count');

    if (error) {
      console.error('❌ Database error:', error);
      return res.status(500).json({
        success: false,
        message: 'Failed to remove territory',
        error: error.message
      });
    }

    console.log('✅ Territory removed successfully');

    return res.status(200).json({
      success: true,
      message: 'Territory removed successfully',
      zipcodes: data[0].zipcodes,
      territory_count: data[0].territory_count
    });

  } catch (err) {
    console.error('❌ Remove territory error:', err);
    return res.status(500).json({
      success: false,
      message: 'Internal server error',
      error: err.message
    });
  }
}

module.exports = {
  register,
  getTerritories,
  addTerritory,
  removeTerritory
};

// ===============================================
// USAGE IN ROUTES
// ===============================================
/*
const express = require('express');
const router = express.Router();
const mobileAuthController = require('../controllers/mobileAuthController');
const { authenticateJWT } = require('../middleware/auth');

// Registration (public)
router.post('/api/mobile/auth/register', mobileAuthController.register);

// Territory management (authenticated)
router.get('/api/mobile/territories', authenticateJWT, mobileAuthController.getTerritories);
router.post('/api/mobile/territories', authenticateJWT, mobileAuthController.addTerritory);
router.delete('/api/mobile/territories/:territoryId', authenticateJWT, mobileAuthController.removeTerritory);

module.exports = router;
*/
