# 🗺️ HOJA DE RUTA: Orbit to Production

**Fecha:** 2026-06-19  
**Objetivo:** Definir pasos concretos para llevar Orbit a producción  
**Timeline:** 5-8 semanas

---

## 📋 VISIÓN GENERAL

```
Hoy (Semana 0):           Frontend 90% + Firebase ✅
                          Backend 0% ❌
                          
Semana 1-2 (Alpha):       Backend MVP ⚠️
                          Llamadas básicas ✅
                          
Semana 3 (Beta):          Backend completo ✅
                          Testing 60% ⚠️
                          
Semana 4-5 (RC):          Testing 95% ✅
                          Seguridad auditada ✅
                          
Semana 6 (Production):    GO LIVE 🚀
```

---

## DECISIÓN CRÍTICA #1: Backend

**DEBES elegir AHORA antes de continuar:**

### Opción A: Construir Backend Propio
```
Ventajas:
  ✅ Control total
  ✅ Custom features
  ✅ Mejor margen
  ✅ Datos propios

Desventajas:
  ❌ 4-6 semanas desarrollo
  ❌ 2 personas requeridas
  ❌ Hosting/infraestructura
  ❌ 24/7 support needed

Tecnología recomendada:
  • Node.js + Express
  • PostgreSQL + Redis
  • Socket.io para signaling
  • Docker containers
  • AWS/Google Cloud
  
Costo estimado:
  • Desarrollo: $15,000-20,000
  • Hosting: $500-1000/mes
  • Maintenance: 0.5 FTE

Tiempo: 4-6 semanas
```

### Opción B: Integrar Twilio
```
Ventajas:
  ✅ 1-2 semanas setup
  ✅ Enterprise support
  ✅ SLA garantizado
  ✅ Auto-scaling
  ✅ Recording built-in

Desventajas:
  ❌ Costo por minuto
  ❌ Menos control
  ❌ Vendor lock-in
  ❌ Datos en Twilio

Costo estimado:
  • Setup: $2,000-5,000
  • Per minute: $0.015-0.03
  • 100,000 min/mes: $1,500-3,000

Tiempo: 1-2 semanas
```

### Opción C: Usar Firebase Solo
```
Ventajas:
  ✅ 0 desarrollo backend
  ✅ Funciona hoy
  ✅ Bajo costo
  ✅ Escalable

Desventajas:
  ❌ Solo P2P (máx 2 usuarios)
  ❌ Sin conferencias
  ❌ Sin recording
  ❌ Sin media server
  ❌ Limitado a Firestore

Costo estimado:
  • Firebase: $0-100/mes (según uso)

Tiempo: Ahora mismo
```

### Opción D: Integrar Agora
```
Ventajas:
  ✅ 1-2 semanas
  ✅ Multi-party video
  ✅ Recording available
  ✅ Good pricing
  ✅ Asia-friendly

Desventajas:
  ❌ Vendor lock-in
  ❌ Data overseas

Costo estimado:
  • Setup: $1,000-3,000
  • Concurrency model: $1-3/1000 min
  • 100,000 min/mes: $100-300

Tiempo: 1-2 semanas
```

---

## SEMANA 1-2: Alpha Launch

### Sprint 1.1: Decide Backend (3 días)
```
Tasks:
  [ ] Evaluó Twilio pricing vs Agora vs custom
  [ ] Decision tomada (recomiendo Twilio)
  [ ] Business case aprobado
  
Owner: CTO/Product  
Deadline: Fin Semana 1
```

### Sprint 1.2: Backend MVP (10 días)

#### Si eligiste TWILIO:
```
Task 1: Twilio Setup (2 días)
  [ ] Account created
  [ ] Credentials secured
  [ ] API keys stored in Firebase Remote Config
  [ ] Documentation reviewed
  
Task 2: Flutter Integration (5 días)
  [ ] TwilioService created (lib/services/twilio_service.dart)
  [ ] Call initiation endpoint
  [ ] Call acceptance logic
  [ ] Call termination
  [ ] Push notification routing
  
Task 3: Testing (3 días)
  [ ] Manual testing on 2 devices
  [ ] Call A→B successful
  [ ] Call B→A successful
  [ ] Hang-up works
  [ ] Error handling
  
Files to create:
  - lib/services/twilio_service.dart
  - lib/screens/communication/incoming_call_screen.dart (new)
  
Testing:
  [ ] Device A calls Device B
  [ ] Notification arrives to B
  [ ] B can accept/reject
  [ ] Audio transfers correctly
  [ ] Call history saved
  
Timeline: 10 días
```

#### Si eligiste CUSTOM BACKEND:
```
Task 1: Backend Scaffolding (3 días)
  [ ] Node.js + Express setup
  [ ] PostgreSQL connection
  [ ] Auth endpoint (/auth/token)
  [ ] Health check endpoint (/health)
  [ ] Deployed to AWS/Google Cloud
  
Task 2: Signaling Server (5 días)
  [ ] Socket.io server setup
  [ ] Join room logic
  [ ] Send offer/answer
  [ ] Send ICE candidates
  [ ] Error handling
  [ ] Tests (50+ test cases)
  
Task 3: Call Routing (4 días)
  [ ] User presence service
  [ ] Call initiation → notify user
  [ ] Push notification trigger
  [ ] Call state management (ringing → accepted → active → ended)
  [ ] Call history logging
  
Files to create:
  - backend/server.js
  - backend/routes/calls.js
  - backend/routes/signaling.js
  - backend/models/call.js
  - backend/middleware/auth.js
  
Testing:
  [ ] Server starts without errors
  [ ] Socket.io connects
  [ ] Basic flow works
  
Timeline: 12 días
```

### Sprint 1.3: Complete Voice Calls (7 días)

```
Task 1: CallService Implementation (4 días)
  [ ] callService.dart reescrito (remove TODOs)
  [ ] startCall() - iniciador
  [ ] acceptCall() - receptor
  [ ] endCall() - ambos
  [ ] Hangup logic
  
Task 2: UI Enhancements (2 días)
  [ ] Incoming call screen mejorada
  [ ] Ringing indicators
  [ ] Accept/Reject buttons
  [ ] Audio routing (speaker/earpiece)
  
Task 3: State Management (1 día)
  [ ] Call state model
  [ ] Provider/Riverpod setup
  
Files modified:
  - lib/services/call_service.dart
  - lib/screens/communication/call_screen.dart
  - lib/screens/communication/video_call_screen.dart (audio support)
  
Testing:
  [ ] Initiate call → other user gets notification
  [ ] Accept call → connection established
  [ ] Reject call → declined message
  [ ] Hang up → session ends
  
Timeline: 7 días

TOTAL SEMANA 1-2: 20 días (3 semanas) → ALPHA READY
```

---

## SEMANA 3: Beta Launch

### Sprint 2.1: Complete Video Calls (5 días)

```
Task 1: Video Stream Integration (3 días)
  [ ] Local video stream capture
  [ ] Remote video stream display
  [ ] Camera toggle (on/off)
  [ ] Mic toggle
  [ ] Speaker selection
  
Task 2: Video UI (2 días)
  [ ] Local video preview (PictureInPicture)
  [ ] Remote video full screen
  [ ] Controls overlay
  [ ] Quality indicator
  
Files modified:
  - lib/screens/communication/video_call_screen.dart
  - lib/services/webrtc_service.dart
  
Testing:
  [ ] Local camera works
  [ ] Remote video displays
  [ ] Video quality good (>500kbps)
  [ ] Audio + video in sync
  
Timeline: 5 días
```

### Sprint 2.2: Testing Suite (8 días)

```
Task 1: Unit Tests (3 días)
  [ ] ChatService tests (20 tests)
  [ ] AuthService tests (15 tests)
  [ ] CallService tests (15 tests)
  [ ] WebRTCService tests (10 tests)
  
Target: 50+ unit tests, 80%+ coverage

Task 2: Widget Tests (3 días)
  [ ] LoginScreen test
  [ ] ChatScreen test
  [ ] VideoCallScreen test
  [ ] VideoHubScreen test
  
Target: 20+ widget tests

Task 3: Integration Tests (2 días)
  [ ] Full auth flow
  [ ] Chat message send/receive
  [ ] Call initiation flow
  
Target: 5+ integration tests

Files created:
  - test/services/call_service_test.dart
  - test/services/chat_service_test.dart
  - test/widgets/chat_screen_test.dart
  - test/widgets/video_call_screen_test.dart
  - test/integration/full_flow_test.dart
  
CI/CD:
  [ ] GitHub Actions configured
  [ ] Tests run on every commit
  [ ] Coverage reports
  
Timeline: 8 días
```

### Sprint 2.3: Monitoring Setup (4 días)

```
Task 1: Sentry Integration (2 días)
  [ ] Sentry.io account created
  [ ] SDK integrated
  [ ] Error tracking active
  [ ] Release tracking
  
Task 2: Firebase Crashlytics (1 día)
  [ ] Already integrated ✅
  [ ] Configure alerting
  [ ] Setup dashboards
  
Task 3: Custom Metrics (1 día)
  [ ] Call quality metrics
  [ ] User engagement
  [ ] Performance metrics
  
Timeline: 4 días

TOTAL SEMANA 3: 17 días → BETA READY
```

---

## SEMANA 4-5: Release Candidate

### Sprint 3.1: Security & Compliance (8 días)

```
Task 1: Security Audit (4 días)
  [ ] Code review por specialist
  [ ] Penetration testing
  [ ] Firestore security rules review
  [ ] Storage security rules review
  [ ] API endpoint security
  [ ] OWASP top 10 check
  
Task 2: Legal & Compliance (3 días)
  [ ] Privacy policy finalizada
  [ ] Terms of Service drafted
  [ ] GDPR compliance plan
  [ ] CCPA compliance plan (si aplica)
  [ ] Data processing agreement
  
Task 3: Documentation (1 día)
  [ ] API docs
  [ ] Security guidelines
  [ ] Deployment guide
  
Timeline: 8 días
```

### Sprint 3.2: Performance Optimization (5 días)

```
Task 1: Load Testing (2 días)
  [ ] Simular 100 concurrent users
  [ ] Simular 100 concurrent calls
  [ ] Database scaling tested
  [ ] Firestore quotas reviewed
  
Task 2: Optimization (2 días)
  [ ] Database indexes optimized
  [ ] Firebase caching configured
  [ ] Image compression optimized
  [ ] Video codec optimized
  
Task 3: Monitoring (1 día)
  [ ] Performance dashboards
  [ ] Alert thresholds set
  
Timeline: 5 días
```

### Sprint 3.3: UAT & Bug Fixes (7 días)

```
Task 1: Internal UAT (3 días)
  [ ] 10+ testers
  [ ] Android phones tested
  [ ] iOS phones tested
  [ ] Different networks tested (wifi, 4G, 3G)
  [ ] Edge cases tested
  
Task 2: Bug Fixes (3 días)
  [ ] P0 bugs fixed (app-breaking)
  [ ] P1 bugs fixed (feature-breaking)
  [ ] P2 bugs logged
  
Task 3: Release Prep (1 día)
  [ ] Release notes prepared
  [ ] Deployment playbook
  [ ] Rollback plan
  
Timeline: 7 días

TOTAL SEMANA 4-5: 20 días → RC READY
```

---

## SEMANA 6: Production Launch

### Sprint 4.1: Pre-Production Deploy (2 días)

```
Task 1: Staging Deployment (1 día)
  [ ] Deploy backend to staging
  [ ] Deploy Firebase security rules
  [ ] Database migrations tested
  
Task 2: Final Testing (1 día)
  [ ] E2E test suite passes
  [ ] Smoke tests pass
  [ ] Performance acceptable
  [ ] Monitoring working
  
Timeline: 2 días
```

### Sprint 4.2: Production Deploy (1 día)

```
Task 1: Deployment (4 horas)
  [ ] Feature flags configured (if using)
  [ ] Canary deployment (10% users)
  [ ] Health checks pass
  [ ] Monitoring alerts active
  
Task 2: Post-Deploy Verification (2 horas)
  [ ] Login works
  [ ] Chat works
  [ ] Calls work
  [ ] Video calls work
  [ ] No P0 errors
  
Task 3: Support Readiness (2 horas)
  [ ] On-call schedule active
  [ ] Support tickets system ready
  [ ] Runbooks prepared
  
Timeline: 1 día

TOTAL SEMANA 6: 3 días → PRODUCTION LIVE 🚀
```

---

## 📊 RESOURCE ALLOCATION

### Team Required

```
BACKEND (Si custom):
  • 1 Senior Backend Engineer: Fulltime (6 semanas)
  • Cost: ~$15,000-20,000

FRONTEND:
  • 1 Flutter Engineer: Fulltime (4 semanas)
  • Cost: ~$10,000

QA/TESTING:
  • 1 QA Engineer: Fulltime (2 semanas)
  • Cost: ~$5,000

DEVOPS:
  • 0.5 DevOps Engineer: Part-time
  • Cost: ~$2,500

SECURITY:
  • 0.5 Security Engineer: Week 4-5
  • Cost: ~$3,000-5,000

MANAGEMENT:
  • 0.5 Product Manager: Fulltime
  • Cost: ~$10,000

TOTAL TEAM COST: ~$45,500-57,500
```

### Budget Estimate

```
Development:      $45,500-57,500
Infrastructure:   $2,000 (Twilio) or $8,000 (custom)
Services:         $500/mo (Sentry, Monitoring)
Legal:            $2,000-3,000 (abogado)
Misc:             $2,000

TOTAL: $51,500-70,500
```

---

## ⚠️ RISKS & MITIGATION

```
Risk 1: Backend delays
  Severity: 🔴 CRITICAL
  Mitigation:
    • Start backend NOW (no waiting)
    • Use Firebase P2P as interim
    • Setup branch-ready for quick switch

Risk 2: WebRTC connection issues
  Severity: 🟠 HIGH
  Mitigation:
    • TURN servers configured
    • Fallback signaling (Firestore)
    • Connection diagnostics service
    • QoS monitoring

Risk 3: Security vulnerabilities discovered late
  Severity: 🔴 CRITICAL
  Mitigation:
    • Start security audit Week 1
    • Penetration testing Week 3
    • Bug bounty program (optional)

Risk 4: Performance not scaling
  Severity: 🟠 HIGH
  Mitigation:
    • Load testing in Week 4
    • Database optimization
    • CDN for media
    • Auto-scaling configured

Risk 5: Firestore quota exceeded
  Severity: 🟡 MEDIUM
  Mitigation:
    • Quota monitoring enabled
    • Alert thresholds set
    • Premium plan ready
    • Data archival strategy

Risk 6: iOS app store rejection
  Severity: 🟡 MEDIUM
  Mitigation:
    • Review guidelines NOW
    • Privacy policy solid
    • Permissions documented
    • Test on iOS early

Risk 7: Android battery drain
  Severity: 🟡 MEDIUM
  Mitigation:
    • Battery testing
    • Background service optimization
    • Notification tuning
    • FCM efficiency
```

---

## 📈 SUCCESS METRICS

### Technical KPIs
```
✅ 99.5% uptime (SLA)
✅ 50ms average latency
✅ <2% call drop rate
✅ >95% test coverage
✅ <100ms video latency
✅ >3.5 star app rating
```

### Business KPIs
```
✅ 100+ beta users
✅ <30 critical bugs at launch
✅ <5 min support response
✅ 70%+ user retention (week 1)
✅ <$0.05 COGS per call minute
```

---

## 🎯 GO/NO-GO DECISION POINTS

### End of Week 1
```
GO if:
  ✅ Backend decision made
  ✅ Alpha launch scheduled
  ✅ Team assembled
  
NO-GO if:
  ❌ Backend delayed
  ❌ Critical bugs found
  ❌ Funding issues
```

### End of Week 3
```
GO if:
  ✅ Video calls working
  ✅ 50+ unit tests passing
  ✅ No P0 bugs
  
NO-GO if:
  ❌ Video integration broken
  ❌ Test coverage <60%
  ❌ Security issues found
```

### End of Week 5
```
GO if:
  ✅ Security audit passed
  ✅ All tests passing
  ✅ Performance acceptable
  ✅ Compliance ready
  
NO-GO if:
  ❌ Security vulnerabilities
  ❌ >10 P0 bugs
  ❌ Performance <acceptable
  ❌ Legal blocking
```

---

## 📋 FINAL CHECKLIST

### Technical Checklist
- [ ] Backend operational
- [ ] All 3 services working (chat, voice, video)
- [ ] Tests 95%+ coverage
- [ ] Monitoring live
- [ ] Rollback plan documented
- [ ] Database backup configured
- [ ] CDN active (if needed)
- [ ] SSL certificates valid
- [ ] Firebase rules validated
- [ ] No hardcoded secrets

### Security Checklist
- [ ] Code reviewed
- [ ] Penetration test done
- [ ] Privacy policy final
- [ ] TOS approved by legal
- [ ] GDPR compliant
- [ ] Data encryption enabled
- [ ] MFA working
- [ ] Secure storage in use
- [ ] Rate limiting active
- [ ] DDoS protection enabled

### Operations Checklist
- [ ] Deployment script tested
- [ ] Rollback script tested
- [ ] Monitoring alerts configured
- [ ] On-call schedule active
- [ ] Support team trained
- [ ] Incident response plan
- [ ] Runbooks prepared
- [ ] Contact info documented
- [ ] Customer support ready
- [ ] Analytics tracking enabled

### Launch Day
- [ ] 1 hour pre-deployment: Full team online
- [ ] Deploy to production
- [ ] Run smoke tests
- [ ] Monitor for 1 hour
- [ ] Announce launch
- [ ] Monitor for 24 hours
- [ ] First incident response

---

**Hoja de Ruta Generada:** 2026-06-19  
**Versión:** 1.0.0  
**Status:** Ready to execute

