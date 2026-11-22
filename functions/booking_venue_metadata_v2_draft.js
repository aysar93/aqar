// Unwired migration proposal: never imported by deployed functions.
function extras(data,previous={}) {
 const out={};
 for(const [key,max]of [['description',10000],['address',500]]) {
  const v=data[key]??previous[key];if(v===undefined)continue;
  if(typeof v!=='string'||v.length>max)throw Error('نص غير صالح');out[key]=v.trim();
 }
 const area=data.area??previous.area,unit=data.areaUnit??previous.areaUnit;
 if(area!==undefined||unit!==undefined){if(typeof area!=='number'||!Number.isFinite(area)||area<=0||area>10000000||!['m2','dunum'].includes(unit))throw Error('مساحة أو وحدة غير صالحة');Object.assign(out,{area,areaUnit:unit});}
 const bathrooms=data.bathrooms??previous.bathrooms;
 if(bathrooms!==undefined){if(!Number.isSafeInteger(bathrooms)||bathrooms<0||bathrooms>100)throw Error('عدد حمامات غير صالح');out.bathrooms=bathrooms;}
 const guestType=data.guestType??previous.guestType;
 if(guestType!==undefined){if(!['families','youth','both'].includes(guestType))throw Error('نوع ضيوف غير صالح');out.guestType=guestType;}
 return out;
}
module.exports={extras};
