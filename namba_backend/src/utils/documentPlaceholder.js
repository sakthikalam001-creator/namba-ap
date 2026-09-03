const fs = require('fs');
const path = require('path');

function getDocumentSvg(filename, reqQuery = {}) {
  const name = reqQuery.name || 'KARTHIKEYAN M';
  const idNo = reqQuery.id || 'XXXX-XXXX-3576';
  
  const isLicense = filename.includes('license') || filename.includes('dl');
  const isBack = filename.includes('back') || filename.includes('rear') || filename.includes('257880554') || filename.includes('12645452') || filename.includes('319604447');
  const isSelfie = filename.includes('selfie') || filename.includes('profile') || filename.includes('208922330') || filename.includes('350791678');
  const isRc = filename.includes('rc') || filename.includes('vehicle');
  const isPan = filename.includes('pan');

  if (isSelfie) {
    return <svg width='400' height='300' xmlns='http://www.w3.org/2000/svg'>
      <defs>
        <linearGradient id='bg' x1='0%' y1='0%' x2='100%' y2='100%'>
          <stop offset='0%' stop-color='#0F172A'/>
          <stop offset='100%' stop-color='#1E293B'/>
        </linearGradient>
        <linearGradient id='avatar' x1='0%' y1='0%' x2='100%' y2='100%'>
          <stop offset='0%' stop-color='#6366F1'/>
          <stop offset='100%' stop-color='#4F46E5'/>
        </linearGradient>
      </defs>
      <rect width='100%' height='100%' fill='url(#bg)' rx='16'/>
      <circle cx='200' cy='120' r='55' fill='url(#avatar)'/>
      <circle cx='200' cy='105' r='24' fill='#FEF08A'/>
      <path d='M160,165 Q200,135 240,165 L240,180 Q200,180 160,180 Z' fill='#38BDF8'/>
      <rect x='110' y='210' width='180' height='26' rx='6' fill='#10B981' opacity='0.2'/>
      <text x='200' y='227' font-family='Arial, sans-serif' font-size='12' font-weight='bold' fill='#34D399' text-anchor='middle'>VERIFIED RIDER SELFIE</text>
      <text x='200' y='255' font-family='Arial, sans-serif' font-size='15' font-weight='bold' fill='#FFFFFF' text-anchor='middle'></text>
      <text x='200' y='275' font-family='Arial, sans-serif' font-size='11' fill='#94A3B8' text-anchor='middle'>NAMBA EXPRESS DELIVERY PARTNER</text>
    </svg>;
  }

  if (isLicense) {
    if (isBack) {
      return <svg width='500' height='320' xmlns='http://www.w3.org/2000/svg'>
        <rect width='100%' height='100%' fill='#F8FAFC' rx='14' stroke='#CBD5E1' stroke-width='2'/>
        <rect x='0' y='0' width='500' height='35' fill='#1E3A8A' rx='14'/>
        <rect x='0' y='25' width='500' height='10' fill='#1E3A8A'/>
        <text x='250' y='23' font-family='Arial, sans-serif' font-size='12' font-weight='bold' fill='#FFFFFF' text-anchor='middle'>TAMIL NADU MOTOR VEHICLES DEPARTMENT</text>
        <rect x='25' y='55' width='450' height='110' rx='8' fill='#FFFFFF' stroke='#E2E8F0'/>
        <text x='40' y='80' font-family='Arial, sans-serif' font-size='11' font-weight='bold' fill='#1E293B'>CLASS OF VEHICLES (COV)</text>
        <text x='40' y='105' font-family='Arial, sans-serif' font-size='12' font-weight='bold' fill='#2563EB'>• MCWG</text>
        <text x='110' y='105' font-family='Arial, sans-serif' font-size='11' fill='#475569'>Motor Cycle With Gear (Non-Transport)</text>
        <text x='40' y='130' font-family='Arial, sans-serif' font-size='12' font-weight='bold' fill='#2563EB'>• LMV</text>
        <text x='110' y='130' font-family='Arial, sans-serif' font-size='11' fill='#475569'>Light Motor Vehicle (Transport / Non-Transport)</text>
        <text x='40' y='152' font-family='Arial, sans-serif' font-size='10' fill='#64748B'>Issued by: RTO TIRUPPUR SOUTH (TN-39) • VALID TILL: 2038</text>
        <rect x='25' y='180' width='300' height='120' rx='8' fill='#FFFFFF' stroke='#E2E8F0'/>
        <text x='40' y='205' font-family='Arial, sans-serif' font-size='11' font-weight='bold' fill='#1E293B'>PERMANENT ADDRESS</text>
        <text x='40' y='225' font-family='Arial, sans-serif' font-size='10.5' fill='#475569'>NO 42, GANDHI NAGAR 2ND STREET,</text>
        <text x='40' y='242' font-family='Arial, sans-serif' font-size='10.5' fill='#475569'>TIRUPPUR, TAMIL NADU - 641603</text>
        <rect x='345' y='180' width='130' height='120' rx='8' fill='#FFFFFF' stroke='#E2E8F0'/>
        <rect x='365' y='200' width='90' height='80' fill='#0F172A' rx='4'/>
        <text x='410' y='245' font-family='Arial, sans-serif' font-size='10' font-weight='bold' fill='#FFFFFF' text-anchor='middle'>QR CODE</text>
      </svg>;
    }
    // License Front
    return <svg width='500' height='320' xmlns='http://www.w3.org/2000/svg'>
      <rect width='100%' height='100%' fill='#FFFBEB' rx='14' stroke='#FCD34D' stroke-width='2'/>
      <rect x='0' y='0' width='500' height='42' fill='#1E3A8A' rx='14'/>
      <rect x='0' y='30' width='500' height='12' fill='#1E3A8A'/>
      <text x='250' y='22' font-family='Arial, sans-serif' font-size='12' font-weight='bold' fill='#FEF08A' text-anchor='middle'>INDIAN UNION DRIVING LICENCE</text>
      <text x='250' y='36' font-family='Arial, sans-serif' font-size='9.5' fill='#E0E7FF' text-anchor='middle'>GOVERNMENT OF TAMIL NADU</text>
      
      <!-- Chip & Photo -->
      <rect x='25' y='60' width='100' height='125' rx='6' fill='#E2E8F0' stroke='#94A3B8'/>
      <circle cx='75' cy='105' r='25' fill='#3B82F6'/>
      <circle cx='75' cy='95' r='12' fill='#FEF08A'/>
      <path d='M55,125 Q75,110 95,125 Z' fill='#1E40AF'/>
      <text x='75' y='170' font-family='Arial, sans-serif' font-size='9' font-weight='bold' fill='#1E293B' text-anchor='middle'>HOLDER PHOTO</text>
      
      <!-- Details -->
      <rect x='140' y='60' width='50' height='38' rx='4' fill='#FBBF24' stroke='#D97706'/>
      <text x='165' y='83' font-family='Arial, sans-serif' font-size='8' font-weight='bold' fill='#78350F' text-anchor='middle'>CHIP</text>
      
      <text x='200' y='75' font-family='Arial, sans-serif' font-size='10' fill='#64748B'>DL NO:</text>
      <text x='250' y='75' font-family='Arial, sans-serif' font-size='13' font-weight='bold' fill='#0F172A'>TN39 20230048291</text>
      
      <text x='140' y='115' font-family='Arial, sans-serif' font-size='10' fill='#64748B'>NAME:</text>
      <text x='190' y='115' font-family='Arial, sans-serif' font-size='13' font-weight='bold' fill='#0F172A'></text>
      
      <text x='140' y='140' font-family='Arial, sans-serif' font-size='10' fill='#64748B'>S/O:</text>
      <text x='190' y='140' font-family='Arial, sans-serif' font-size='11' font-weight='bold' fill='#334155'>MURUGESAN</text>
      
      <text x='140' y='165' font-family='Arial, sans-serif' font-size='10' fill='#64748B'>DOB:</text>
      <text x='190' y='165' font-family='Arial, sans-serif' font-size='11' font-weight='bold' fill='#334155'>15-08-1998</text>
      
      <text x='320' y='165' font-family='Arial, sans-serif' font-size='10' fill='#64748B'>BLOOD GP:</text>
      <text x='390' y='165' font-family='Arial, sans-serif' font-size='11' font-weight='bold' fill='#DC2626'>O +VE</text>
      
      <!-- Bottom Strip -->
      <rect x='25' y='200' width='450' height='100' rx='8' fill='#FFFFFF' stroke='#E2E8F0'/>
      <text x='40' y='225' font-family='Arial, sans-serif' font-size='10' fill='#64748B'>VALIDITY (NT):</text>
      <text x='130' y='225' font-family='Arial, sans-serif' font-size='11' font-weight='bold' fill='#059669'>14-08-2038</text>
      <text x='250' y='225' font-family='Arial, sans-serif' font-size='10' fill='#64748B'>AUTHORISATION:</text>
      <text x='360' y='225' font-family='Arial, sans-serif' font-size='11' font-weight='bold' fill='#2563EB'>MCWG, LMV</text>
      <line x1='40' y1='245' x2='460' y2='245' stroke='#E2E8F0'/>
      <text x='40' y='270' font-family='Arial, sans-serif' font-size='9.5' fill='#94A3B8'>ISSUING AUTHORITY: RTO TIRUPPUR SOUTH • STATE OF TAMIL NADU</text>
      <text x='40' y='288' font-family='Arial, sans-serif' font-size='9' font-weight='bold' fill='#10B981'>✓ OFFICIAL VERIFIED DRIVING LICENCE RECORD</text>
    </svg>;
  }

  // Aadhaar Document
  if (isBack) {
    return <svg width='500' height='320' xmlns='http://www.w3.org/2000/svg'>
      <rect width='100%' height='100%' fill='#FFFFFF' rx='14' stroke='#CBD5E1' stroke-width='2'/>
      <rect x='0' y='0' width='500' height='10' fill='#EA580C' rx='14'/>
      <rect x='0' y='10' width='500' height='10' fill='#FFFFFF'/>
      <rect x='0' y='20' width='500' height='10' fill='#16A34A'/>
      
      <text x='250' y='55' font-family='Arial, sans-serif' font-size='13' font-weight='bold' fill='#9A3412' text-anchor='middle'>Unique Identification Authority of India</text>
      <line x1='30' y1='68' x2='470' y2='68' stroke='#EA580C' stroke-width='1.5'/>
      
      <text x='40' y='100' font-family='Arial, sans-serif' font-size='11' font-weight='bold' fill='#1E293B'>Address:</text>
      <text x='40' y='122' font-family='Arial, sans-serif' font-size='11' fill='#334155'>S/O: Murugesan, 42 Gandhi Nagar,</text>
      <text x='40' y='142' font-family='Arial, sans-serif' font-size='11' fill='#334155'>2nd Street, Kangeyam Road, Tiruppur,</text>
      <text x='40' y='162' font-family='Arial, sans-serif' font-size='11' fill='#334155'>Tamil Nadu, 641603</text>
      
      <text x='40' y='195' font-family='Arial, sans-serif' font-size='11' font-weight='bold' fill='#1E293B'>முகவரி:</text>
      <text x='40' y='215' font-family='Arial, sans-serif' font-size='10.5' fill='#334155'>த/பெ: முருகேசன், 42 காந்தி நகர் 2வது தெரு,</text>
      <text x='40' y='233' font-family='Arial, sans-serif' font-size='10.5' fill='#334155'>காங்கேயம் ரோடு, திருப்பூர், தமிழ்நாடு - 641603</text>
      
      <!-- QR code -->
      <rect x='345' y='90' width='120' height='120' fill='#F8FAFC' stroke='#94A3B8' rx='6'/>
      <rect x='360' y='105' width='90' height='90' fill='#0F172A' rx='4'/>
      <text x='405' y='155' font-family='Arial, sans-serif' font-size='10' font-weight='bold' fill='#FFFFFF' text-anchor='middle'>AADHAAR QR</text>
      
      <rect x='0' y='270' width='500' height='50' fill='#FEF2F2' rx='14'/>
      <rect x='0' y='270' width='500' height='10' fill='#FEF2F2'/>
      <text x='250' y='298' font-family='Arial, sans-serif' font-size='16' font-weight='bold' fill='#B91C1C' text-anchor='middle' letter-spacing='3'>5489 3672 9014</text>
    </svg>;
  }

  // Aadhaar Front
  return <svg width='500' height='320' xmlns='http://www.w3.org/2000/svg'>
    <rect width='100%' height='100%' fill='#FFFFFF' rx='14' stroke='#CBD5E1' stroke-width='2'/>
    <!-- Tricolor Top Bar -->
    <rect x='0' y='0' width='500' height='8' fill='#EA580C' rx='14'/>
    <rect x='0' y='8' width='500' height='8' fill='#FFFFFF'/>
    <rect x='0' y='16' width='500' height='8' fill='#16A34A'/>
    
    <!-- Emblem & Header -->
    <text x='250' y='50' font-family='Arial, sans-serif' font-size='12' font-weight='bold' fill='#9A3412' text-anchor='middle'>பாரத அரசு • GOVERNMENT OF INDIA</text>
    <line x1='30' y1='62' x2='470' y2='62' stroke='#EA580C' stroke-width='1.5'/>
    
    <!-- Photo Box -->
    <rect x='35' y='80' width='105' height='130' rx='6' fill='#F1F5F9' stroke='#CBD5E1'/>
    <circle cx='87' cy='130' r='28' fill='#6366F1'/>
    <circle cx='87' cy='120' r='14' fill='#FEF08A'/>
    <path d='M65,155 Q87,140 109,155 Z' fill='#312E81'/>
    <text x='87' y='195' font-family='Arial, sans-serif' font-size='9' font-weight='bold' fill='#475569' text-anchor='middle'>PHOTO</text>
    
    <!-- Details -->
    <text x='160' y='105' font-family='Arial, sans-serif' font-size='11' fill='#64748B'>பெயர் / Name:</text>
    <text x='160' y='125' font-family='Arial, sans-serif' font-size='14' font-weight='bold' fill='#0F172A'></text>
    
    <text x='160' y='155' font-family='Arial, sans-serif' font-size='11' fill='#64748B'>பிறந்த தேதி / DOB:</text>
    <text x='160' y='173' font-family='Arial, sans-serif' font-size='12' font-weight='bold' fill='#334155'>15/08/1998</text>
    
    <text x='160' y='200' font-family='Arial, sans-serif' font-size='11' fill='#64748B'>பாலினம் / Gender:</text>
    <text x='260' y='200' font-family='Arial, sans-serif' font-size='12' font-weight='bold' fill='#334155'>ஆண் / MALE</text>
    
    <!-- Bottom Aadhaar Number Box -->
    <rect x='0' y='250' width='500' height='70' fill='#FFF1F2' rx='14'/>
    <rect x='0' y='250' width='500' height='15' fill='#FFF1F2'/>
    <text x='250' y='285' font-family='Arial, sans-serif' font-size='19' font-weight='bold' fill='#BE123C' text-anchor='middle' letter-spacing='4'>5489 3672 9014</text>
    <text x='250' y='306' font-family='Arial, sans-serif' font-size='10' font-weight='bold' fill='#059669' text-anchor='middle'>✓ ஆதார் - சாதாரண மனிதனின் உரிமை</text>
  </svg>;
}

module.exports = { getDocumentSvg };
