function getDocumentSvg(filename, reqQuery = {}) {
  const name = (reqQuery && reqQuery.name) ? reqQuery.name : 'KARTHIKEYAN M';
  const fname = String(filename || '').toLowerCase();
  
  const isLicense = fname.includes('license') || fname.includes('dl');
  const isBack = fname.includes('back') || fname.includes('rear') || fname.includes('257880554') || fname.includes('12645452') || fname.includes('319604447');
  const isSelfie = fname.includes('selfie') || fname.includes('profile') || fname.includes('208922330') || fname.includes('350791678');

  if (isSelfie) {
    return "<svg width='400' height='300' xmlns='http://www.w3.org/2000/svg'>" +
      "<rect width='100%' height='100%' fill='#0F172A' rx='16'/>" +
      "<circle cx='200' cy='120' r='55' fill='#6366F1'/>" +
      "<circle cx='200' cy='105' r='24' fill='#FEF08A'/>" +
      "<path d='M160,165 Q200,135 240,165 L240,180 Q200,180 160,180 Z' fill='#38BDF8'/>" +
      "<rect x='110' y='210' width='180' height='26' rx='6' fill='#10B981' opacity='0.2'/>" +
      "<text x='200' y='227' font-family='Arial, sans-serif' font-size='12' font-weight='bold' fill='#34D399' text-anchor='middle'>VERIFIED RIDER SELFIE</text>" +
      "<text x='200' y='255' font-family='Arial, sans-serif' font-size='15' font-weight='bold' fill='#FFFFFF' text-anchor='middle'>" + name + "</text>" +
      "<text x='200' y='275' font-family='Arial, sans-serif' font-size='11' fill='#94A3B8' text-anchor='middle'>NAMBA EXPRESS DELIVERY PARTNER</text>" +
    "</svg>";
  }

  if (isLicense) {
    if (isBack) {
      return "<svg width='500' height='320' xmlns='http://www.w3.org/2000/svg'>" +
        "<rect width='100%' height='100%' fill='#F8FAFC' rx='14' stroke='#CBD5E1' stroke-width='2'/>" +
        "<rect x='0' y='0' width='500' height='35' fill='#1E3A8A' rx='14'/>" +
        "<text x='250' y='23' font-family='Arial, sans-serif' font-size='12' font-weight='bold' fill='#FFFFFF' text-anchor='middle'>TAMIL NADU MOTOR VEHICLES DEPARTMENT</text>" +
        "<text x='40' y='105' font-family='Arial, sans-serif' font-size='12' font-weight='bold' fill='#2563EB'>• MCWG, LMV</text>" +
        "<text x='40' y='152' font-family='Arial, sans-serif' font-size='10' fill='#64748B'>Issued by: RTO TIRUPPUR SOUTH (TN-39) • VALID TILL: 2038</text>" +
      "</svg>";
    }
    return "<svg width='500' height='320' xmlns='http://www.w3.org/2000/svg'>" +
      "<rect width='100%' height='100%' fill='#FFFBEB' rx='14' stroke='#FCD34D' stroke-width='2'/>" +
      "<rect x='0' y='0' width='500' height='42' fill='#1E3A8A' rx='14'/>" +
      "<text x='250' y='26' font-family='Arial, sans-serif' font-size='12' font-weight='bold' fill='#FEF08A' text-anchor='middle'>INDIAN UNION DRIVING LICENCE</text>" +
      "<text x='40' y='80' font-family='Arial, sans-serif' font-size='11' font-weight='bold' fill='#0F172A'>DL NO: TN39 20230048291</text>" +
      "<text x='40' y='105' font-family='Arial, sans-serif' font-size='13' font-weight='bold' fill='#0F172A'>" + name + "</text>" +
    "</svg>";
  }

  if (isBack) {
    return "<svg width='500' height='320' xmlns='http://www.w3.org/2000/svg'>" +
      "<rect width='100%' height='100%' fill='#FFFFFF' rx='14' stroke='#CBD5E1' stroke-width='2'/>" +
      "<text x='250' y='55' font-family='Arial, sans-serif' font-size='13' font-weight='bold' fill='#9A3412' text-anchor='middle'>Unique Identification Authority of India</text>" +
      "<text x='250' y='298' font-family='Arial, sans-serif' font-size='16' font-weight='bold' fill='#B91C1C' text-anchor='middle'>5489 3672 9014</text>" +
    "</svg>";
  }

  return "<svg width='500' height='320' xmlns='http://www.w3.org/2000/svg'>" +
    "<rect width='100%' height='100%' fill='#FFFFFF' rx='14' stroke='#CBD5E1' stroke-width='2'/>" +
    "<text x='250' y='50' font-family='Arial, sans-serif' font-size='12' font-weight='bold' fill='#9A3412' text-anchor='middle'>GOVERNMENT OF INDIA</text>" +
    "<text x='160' y='125' font-family='Arial, sans-serif' font-size='14' font-weight='bold' fill='#0F172A'>" + name + "</text>" +
    "<text x='250' y='285' font-family='Arial, sans-serif' font-size='19' font-weight='bold' fill='#BE123C' text-anchor='middle'>5489 3672 9014</text>" +
  "</svg>";
}

module.exports = { getDocumentSvg };
