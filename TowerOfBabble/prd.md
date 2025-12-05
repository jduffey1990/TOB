# Tower of Babble - Product Requirements Document

**Tagline:** "The closest we can get to God is prayer"

**Vision:** A mobile prayer companion that helps users create, save, and listen to personalized prayers with text-to-speech technology. Free tier for casual users, Pro tier for dedicated prayer practitioners.

---

## Current Status (MVP Complete ✅)
**Completed:** December 4, 2025

- [x] Animated splash screen with title/tagline fade-in
- [x] Mock login (tap "Enter" to proceed)
- [x] Prayer list view with empty state
- [x] Create new prayers with title and text
- [x] Edit existing prayers
- [x] Delete prayers (swipe to delete)
- [x] Basic text-to-speech playback (iOS native AVSpeechSynthesizer)
- [x] Local storage using UserDefaults
- [x] Floating blue + button for new prayers
- [x] Play/Stop controls during prayer playback

**Tech Stack:**
- Swift + SwiftUI
- UserDefaults for persistence
- AVFoundation for TTS
- No backend (local only)

---

## Phase 1: Polish & Foundation 🎨
**Goal:** Make the MVP production-ready and establish good development practices

### 1.1 Splash Screen Improvements
- [ ] Smoother fade transitions (adjust timing curves)
- [ ] Add subtle background animation (floating particles? light rays?)
- [ ] Better typography/logo design
- [ ] Consider adding a skip button after first launch

### 1.2 Development Infrastructure
- [ ] Initialize Git repository
- [ ] Create GitHub repo (private initially)
- [ ] Set up .gitignore for Xcode projects
- [ ] First commit and push
- [ ] Add README.md with setup instructions

### 1.3 Branding & Assets
- [ ] Design app icon
- [ ] Create launch screen assets
- [ ] Define color palette (currently using system blue)
- [ ] Typography standards
- [ ] Design language guide

### 1.4 Code Quality
- [ ] Add error handling for TTS failures
- [ ] Improve data validation (empty titles, etc.)
- [ ] Add loading states where needed
- [ ] Better empty states with illustrations

**Timeline:** 1-2 weeks  
**Blockers:** None  
**Dependencies:** None

---

## Phase 2: User Authentication & Account System 🔐
**Goal:** Enable user accounts to prepare for cloud sync and tiered features

### 2.1 Backend Decision
**Options to evaluate:**
1. **Firebase** (easiest, fastest)
   - ✅ Auth built-in
   - ✅ Firestore for data
   - ✅ Quick setup
   - ❌ Costs scale with usage
   - ❌ Vendor lock-in

2. **AWS Amplify** (more control)
   - ✅ Flexible
   - ✅ Integrates with other AWS services
   - ❌ Steeper learning curve
   - ❌ More configuration

3. **Custom Backend** (your Django/Node.js experience)
   - ✅ Full control
   - ✅ Use your existing skills
   - ✅ Can host cheaply
   - ❌ More upfront work
   - ❌ You maintain everything

**Recommendation:** Start with Firebase for speed, migrate to custom backend later if needed.

### 2.2 Authentication Features
- [ ] Email/password registration
- [ ] Email/password login
- [ ] Password reset flow
- [ ] "Sign in with Apple" (required for App Store)
- [ ] Optional: Google Sign-In
- [ ] Logout functionality
- [ ] Account settings screen
- [ ] Delete account option

### 2.3 User Profile
- [ ] Basic profile (name, email)
- [ ] Account type indicator (Free/Pro)
- [ ] Subscription status display
- [ ] Usage statistics (prayers created, times played, etc.)

**Timeline:** 2-3 weeks  
**Blockers:** Backend choice decision  
**Dependencies:** Phase 1 complete

---

## Phase 3: Free Tier Features (Post-Auth) 🆓
**Goal:** Define and implement the base free experience

### 3.1 Free Tier Limitations
**Proposed Limits:**
- [ ] Maximum 5 saved prayers
- [ ] 2 voice options (male/female, US English only)
- [ ] Local storage only (no cloud sync)
- [ ] Basic playback controls
- [ ] Ads? (TBD - may not want to distract from prayer experience)

### 3.2 Prayer Templates Library
- [ ] Pre-built common prayers (Lord's Prayer, Hail Mary, etc.)
- [ ] Category organization (morning, evening, gratitude, intercession)
- [ ] "Use Template" to create new prayer from template
- [ ] Search/filter templates
- [ ] 20-30 starter templates included

### 3.3 UI Indicators
- [ ] "X/5 prayers saved" counter
- [ ] "Upgrade to Pro" prompts (non-intrusive)
- [ ] Feature discovery tooltips
- [ ] Onboarding flow for new users

### 3.4 Data Migration
- [ ] Migrate from UserDefaults to Core Data
- [ ] Cloud sync preparation (data models ready)
- [ ] Export prayers (backup functionality)

**Timeline:** 2 weeks  
**Blockers:** Phase 2 auth complete  
**Dependencies:** Backend infrastructure

---

## Phase 4: Pro Tier Features 💎
**Goal:** Create compelling premium features worth paying for

### 4.1 Core Pro Features
- [ ] **Unlimited saved prayers** (remove 5-prayer limit)
- [ ] **Cloud backup & sync** across all user devices
- [ ] **Premium voice library** (10-15 high-quality voices)
- [ ] **AI prayer completion/suggestions** (GPT integration)
- [ ] **Custom voice styles** (see 4.3)
- [ ] **Prayer builder tools** (see 4.4)
- [ ] **Advanced playback controls** (speed, pause, repeat)
- [ ] **No upgrade prompts** (cleaner experience)

### 4.2 AI Prayer Completion
**How it works:**
- User starts typing a prayer
- AI suggests completions based on:
  - Prayer type/context
  - User's past prayers (personalized)
  - Traditional prayer structures
- User can accept, reject, or edit suggestions

**Technical:**
- [ ] OpenAI API integration
- [ ] Prompt engineering for respectful prayer content
- [ ] Token usage monitoring/limits
- [ ] Fallback if API unavailable
- [ ] Privacy considerations (user data handling)

### 4.3 Custom Voice Styles
**Proposed Styles:**
- [ ] Southern Baptist Preacher (passionate, rhythmic)
- [ ] Catholic Priest (formal, reverent)
- [ ] Contemplative/Meditative (soft, slow)
- [ ] Charismatic (energetic, joyful)
- [ ] Child's Voice (for bedtime prayers)
- [ ] User's Own Voice (record and clone - future phase?)

**Technical Options:**
1. **ElevenLabs API** (best quality, expensive)
2. **Azure Speech** (good quality, Microsoft)
3. **Google Cloud TTS** (reliable, good pricing)
4. **AWS Polly** (neural voices available)

**Recommendation:** Start with Azure or Google for cost-effectiveness

### 4.4 Prayer Builder Tools
- [ ] **Saved Intentions:** Common people/situations to pray for
  - Add "Mom's health", "Friend Sarah", "Work situation"
  - Quick-insert into prayers
- [ ] **Prayer Components Library**
  - Saved opening lines
  - Saved closing lines
  - Common phrases/scriptures
  - Mix and match to build prayers quickly
- [ ] **Prayer Categories/Tags**
  - Organize prayers by type
  - Filter and search
- [ ] **Prayer History**
  - When last prayed
  - How many times prayed
  - Streak tracking?

### 4.5 Cloud Sync Architecture
- [ ] Design sync strategy (optimistic updates)
- [ ] Conflict resolution (last-write-wins vs. merge)
- [ ] Offline mode handling
- [ ] Sync status indicators
- [ ] Manual sync trigger option

**Timeline:** 4-6 weeks  
**Blockers:** Cost analysis for AI/TTS APIs, backend scaling plan  
**Dependencies:** Phase 3 complete, payment system ready

---

## Phase 5: Monetization & Payments 💰
**Goal:** Implement subscription system and generate revenue

### 5.1 Pricing Strategy
**Proposed Pricing:**
- Free: $0 (5 prayers, basic voices, local only)
- Pro: **$9.99/year** or **$1.99/month**
  - Unlimited prayers
  - Cloud sync
  - Premium voices
  - AI features

**Considerations:**
- Annual pricing encourages commitment (better retention)
- Monthly option for flexibility
- Lifetime option? ($39.99 one-time)
- Family plan? (up to 5 accounts, $14.99/year)

**Competitive Analysis Needed:**
- Research similar apps (prayer apps, Bible apps with audio)
- What do they charge?
- What features do they offer?

### 5.2 In-App Purchases (IAP)
- [ ] Set up App Store Connect
- [ ] Create IAP products (subscriptions)
- [ ] Implement StoreKit 2
- [ ] Purchase flow UI
- [ ] Receipt validation (server-side)
- [ ] Restore purchases functionality
- [ ] Handle subscription lifecycle (trial, active, expired, canceled)

### 5.3 Payment UX
- [ ] Upgrade prompts (strategic placement)
- [ ] Feature comparison table (Free vs Pro)
- [ ] "Why go Pro?" explanation
- [ ] Testimonials/social proof
- [ ] Free trial? (7 days? 14 days?)
- [ ] Refund policy clarity
- [ ] Manage subscription screen

### 5.4 Revenue Operations
- [ ] Set up Stripe/payment processor (if needed for backend)
- [ ] Analytics for conversion tracking
- [ ] A/B test pricing/messaging
- [ ] Customer support system for billing issues
- [ ] Promo codes/discount system

**Timeline:** 3-4 weeks  
**Blockers:** App Store approval process, tax/legal setup  
**Dependencies:** Phase 4 features complete (have something worth paying for!)

---

## Phase 6: Voice Quality Improvements 🎙️
**Goal:** Significantly improve text-to-speech quality for better prayer experience

### 6.1 Free Tier Voice Improvements
- [ ] Test all iOS system voices, pick best 2-3
- [ ] Optimize speech rate and pitch for prayer context
- [ ] Add pause handling (commas, periods, line breaks)
- [ ] Better pronunciation of religious terms

### 6.2 Pro Tier Premium Voices
**Requirements:**
- Natural, human-like quality
- Multiple accents/languages (start with English variants)
- Emotional range (reverent, joyful, contemplative)
- Consistent performance

**Implementation:**
- [ ] Select TTS provider (ElevenLabs, Azure, Google)
- [ ] API integration
- [ ] Voice preview/selection UI
- [ ] Caching strategy (reduce API calls)
- [ ] Offline fallback voices
- [ ] Cost monitoring dashboard

### 6.3 Advanced Audio Features
- [ ] Background music/ambience option (optional soft music)
- [ ] Adjustable playback speed (0.5x to 1.5x)
- [ ] Audio effects (reverb for "church" feel?)
- [ ] Export prayer as audio file
- [ ] Share audio with others

**Timeline:** 2-3 weeks  
**Blockers:** API costs approval, quality testing  
**Dependencies:** Phase 4 complete

---

## Future Phases / Nice-to-Haves 🚀

### Community Features
- [ ] Share prayers publicly (opt-in)
- [ ] Prayer requests from community
- [ ] Pray for others' intentions
- [ ] Prayer groups/circles
- [ ] Social features (likes, comments?)

### Enhanced Personalization
- [ ] Daily prayer reminders/notifications
- [ ] Prayer streaks and habits
- [ ] Personalized prayer suggestions based on history
- [ ] Integration with calendar (pray for upcoming events)
- [ ] Location-based suggestions (pray for your city)

### Integrations
- [ ] Bible app integrations
- [ ] Church/parish connections
- [ ] Apple Health (mindfulness minutes)
- [ ] Shortcuts app support
- [ ] Widget for home screen

### Accessibility
- [ ] VoiceOver optimization
- [ ] Dynamic type support (larger text)
- [ ] High contrast mode
- [ ] Reduce motion option
- [ ] Multiple language support (Spanish, Portuguese, etc.)

### Technical Improvements
- [ ] Migrate to Core Data (better performance than UserDefaults)
- [ ] Add unit tests (critical paths)
- [ ] Add UI tests (smoke tests)
- [ ] Performance monitoring
- [ ] Crash reporting (Firebase Crashlytics)
- [ ] Analytics (user behavior, feature usage)

---

## Open Questions & Decisions Needed ❓

### Backend & Infrastructure
- **Q:** Firebase vs. Custom Backend?
  - **Leaning toward:** Firebase initially for speed
  - **Decision by:** Phase 2 start

- **Q:** How to handle user data privacy/security?
  - Prayers are sensitive religious content
  - GDPR/privacy compliance needed
  - Encryption at rest and in transit

### Monetization
- **Q:** What's the right price point?
  - **Need to research:** Competitor pricing
  - **Test:** Different price points in soft launch

- **Q:** Free trial or freemium only?
  - **Consideration:** Free trial may increase conversions
  - **Risk:** Support burden from trial users

- **Q:** Ads in free tier?
  - **Pro:** Revenue from free users
  - **Con:** Distracting during prayer, may harm brand
  - **Recommendation:** No ads, pure freemium model

### Features & Scope
- **Q:** How many prayer templates to include?
  - Start with 20-30 covering major traditions
  - Grow library over time based on requests

- **Q:** Which voice provider for Pro tier?
  - **Need to test:** Quality vs. cost tradeoff
  - **Build:** Voice comparison demo

- **Q:** Should we support multiple religions?
  - Start Christian-focused (your target market)
  - Expand to other faiths in future if demand exists

### Technical
- **Q:** iOS only or Android too?
  - **Phase 1-5:** iOS only (you're learning iOS)
  - **Future:** Android if successful (React Native rewrite?)

- **Q:** iPad optimization?
  - iOS app will work on iPad automatically
  - Dedicated iPad UI is Phase 7+

---

## Success Metrics 📊

### Phase 1 (MVP Polish)
- App doesn't crash
- Smooth animations
- Code is maintainable

### Phase 2-3 (Free Tier)
- 1,000 user signups (6 months)
- 20% weekly active user rate
- Average 3 prayers saved per user

### Phase 4-5 (Pro Tier Launch)
- 5% conversion rate (free to paid)
- 50 paying subscribers (first month)
- <5% monthly churn rate
- $500 MRR (monthly recurring revenue)

### Long-term (12 months)
- 10,000 total users
- 500 paying subscribers
- $5,000 MRR
- 4.5+ star rating in App Store
- Featured in App Store? (aspirational)

---

## Risk Assessment ⚠️

### Technical Risks
- **TTS API costs spiral:** Implement caching, usage limits
- **Backend downtime:** Build robust offline mode
- **App Store rejection:** Follow guidelines carefully, test thoroughly

### Business Risks
- **Low conversion rate:** Price too high or features not compelling
  - Mitigation: A/B test pricing, add more Pro features
- **High churn:** Users subscribe then immediately cancel
  - Mitigation: Excellent onboarding, quick value delivery
- **Competition:** Established prayer apps add similar features
  - Mitigation: Focus on quality, unique voice styles, AI differentiation

### Market Risks
- **Niche market too small:** Not enough people want prayer TTS app
  - Mitigation: Validate with beta users early
- **Religious sensitivity:** Features offend certain groups
  - Mitigation: Be respectful, allow customization, clear communication

---

## Next Steps (Immediate) ✅

**This week:**
1. ✅ Complete MVP (DONE!)
2. ✅ Create this PRD.md file and save in Xcode project
3. [ ] Initialize Git repo and make first commit
4. [ ] Test MVP thoroughly, fix any bugs
5. [ ] Show to 3-5 friends for initial feedback

**Next week:**
1. [ ] Decide on backend (Firebase vs. Custom)
2. [ ] Improve splash screen animation
3. [ ] Design app icon (or hire designer)
4. [ ] Research TTS provider options and pricing
5. [ ] Write user stories for Phase 2 (Authentication)

**Next month:**
1. [ ] Complete Phase 1 (Polish)
2. [ ] Start Phase 2 (Authentication)
3. [ ] Set up TestFlight for beta testing
4. [ ] Build landing page/website for marketing

---

## Notes & Ideas 💡

- Consider prayer journal feature (write reflections after praying)
- Daily verse integration with prayers
- Audio recordings of user's own voice reading prayers
- Prayer walk mode (GPS-based prayers for locations)
- Fasting tracker integration
- Rosary/liturgical calendar integration for Catholic users
- Hebrew/Latin pronunciation guides for traditional prayers
- "Pray with me" feature (synchronized group prayer times)

---

## Current File Structure
```
TowerOfBabble/
├── TowerOfBabble.xcodeproj/          # Xcode project file
├── TowerOfBabble/                     # Main app folder
│   ├── Assets.xcassets/               # Images, icons, colors
│   ├── TowerOfBabbleApp.swift         # App entry point
│   ├── SplashView.swift               # Animated splash screen
│   ├── PrayersListView.swift          # Main list of prayers
│   ├── PrayerEditorView.swift         # Create/edit prayer screen
│   ├── PrayerManager.swift            # Data model & TTS logic
│   └── PRD.md                         # This file (product roadmap)
└── README.md                          # Project documentation
```

**Last Updated:** December 4, 2025  
**Project Owner:** Jordan Duffey / Fox Dog Software Development LLC  
**Target Launch:** TBD (aim for beta Q2 2026?)
