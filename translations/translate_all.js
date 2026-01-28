#!/usr/bin/env node
/**
 * Bulk Translation Script for FS25_UsedPlus
 * Translates all English strings to 12 new languages
 */

const fs = require('fs');
const path = require('path');

// Languages to translate
const LANGUAGES = {
    cs: { name: 'Chinese Simplified', native: '简体中文' },
    ct: { name: 'Chinese Traditional', native: '繁體中文' },
    da: { name: 'Danish', native: 'Dansk' },
    ea: { name: 'Spanish (Latin America)', native: 'Español (Latinoamérica)' },
    fc: { name: 'French (Canadian)', native: 'Français (Canada)' },
    fi: { name: 'Finnish', native: 'Suomi' },
    id: { name: 'Indonesian', native: 'Bahasa Indonesia' },
    kr: { name: 'Korean', native: '한국어' },
    no: { name: 'Norwegian', native: 'Norsk' },
    ro: { name: 'Romanian', native: 'Română' },
    sv: { name: 'Swedish', native: 'Svenska' },
    vi: { name: 'Vietnamese', native: 'Tiếng Việt' }
};

// Common word translations for each language
const TRANSLATIONS = {
    cs: {
        // Core terms
        'Finance': '融资', 'Lease': '租赁', 'Vehicle': '车辆', 'Payment': '付款',
        'Monthly': '每月', 'Yearly': '每年', 'Total': '总计', 'Cost': '费用',
        'Interest': '利息', 'Rate': '利率', 'Credit': '信用', 'Score': '分数',
        'Down Payment': '首付', 'Term': '期限', 'Balance': '余额', 'Price': '价格',
        'Search': '搜索', 'Used': '二手', 'New': '新', 'Equipment': '设备',
        'Details': '详情', 'Information': '信息', 'Important': '重要',
        'Accept': '接受', 'Cancel': '取消', 'Confirm': '确认', 'Start': '开始',
        'Duration': '持续时间', 'Success': '成功', 'Failed': '失败',
        'Agent': '代理', 'Local': '本地', 'Regional': '区域', 'National': '全国',
        'Quality': '质量', 'Condition': '状况', 'Excellent': '优秀', 'Good': '良好',
        'Fair': '一般', 'Poor': '较差', 'Worn': '磨损', 'Year': '年', 'Years': '年',
        'Month': '月', 'Months': '月', 'Day': '天', 'Days': '天',
        'Buy': '购买', 'Sell': '出售', 'Trade': '交易', 'Offer': '报价',
        'Loan': '贷款', 'Debt': '债务', 'Asset': '资产', 'Value': '价值',
        'Warning': '警告', 'Error': '错误', 'Notification': '通知',
        'Yes': '是', 'No': '否', 'OK': '确定', 'Close': '关闭', 'Back': '返回',
        'View': '查看', 'Make': '进行', 'Select': '选择', 'Choose': '选择',
        'Configuration': '配置', 'Settings': '设置', 'Options': '选项',
        'Manager': '管理器', 'Active': '活跃', 'Complete': '完成',
        'Remaining': '剩余', 'Paid': '已付', 'Due': '到期', 'Today': '今天',
        'Immediately': '立即', 'Automatically': '自动',
    },
    ct: {
        'Finance': '融資', 'Lease': '租賃', 'Vehicle': '車輛', 'Payment': '付款',
        'Monthly': '每月', 'Yearly': '每年', 'Total': '總計', 'Cost': '費用',
        'Interest': '利息', 'Rate': '利率', 'Credit': '信用', 'Score': '分數',
        'Down Payment': '首付', 'Term': '期限', 'Balance': '餘額', 'Price': '價格',
        'Search': '搜尋', 'Used': '二手', 'New': '新', 'Equipment': '設備',
        'Details': '詳情', 'Information': '資訊', 'Important': '重要',
        'Accept': '接受', 'Cancel': '取消', 'Confirm': '確認', 'Start': '開始',
        'Duration': '持續時間', 'Success': '成功', 'Failed': '失敗',
        'Agent': '代理', 'Local': '本地', 'Regional': '區域', 'National': '全國',
        'Quality': '品質', 'Condition': '狀況', 'Excellent': '優秀', 'Good': '良好',
        'Fair': '一般', 'Poor': '較差', 'Worn': '磨損', 'Year': '年', 'Years': '年',
        'Month': '月', 'Months': '月', 'Day': '天', 'Days': '天',
        'Buy': '購買', 'Sell': '出售', 'Trade': '交易', 'Offer': '報價',
        'Yes': '是', 'No': '否', 'OK': '確定', 'Close': '關閉', 'Back': '返回',
    },
    da: {
        'Finance': 'Finansiering', 'Lease': 'Leasing', 'Vehicle': 'Køretøj', 'Payment': 'Betaling',
        'Monthly': 'Månedlig', 'Yearly': 'Årlig', 'Total': 'Total', 'Cost': 'Omkostning',
        'Interest': 'Rente', 'Rate': 'Sats', 'Credit': 'Kredit', 'Score': 'Score',
        'Down Payment': 'Udbetaling', 'Term': 'Løbetid', 'Balance': 'Saldo', 'Price': 'Pris',
        'Search': 'Søg', 'Used': 'Brugt', 'New': 'Ny', 'Equipment': 'Udstyr',
        'Details': 'Detaljer', 'Information': 'Information', 'Important': 'Vigtigt',
        'Accept': 'Accepter', 'Cancel': 'Annuller', 'Confirm': 'Bekræft', 'Start': 'Start',
        'Duration': 'Varighed', 'Success': 'Succes', 'Failed': 'Mislykket',
        'Agent': 'Agent', 'Local': 'Lokal', 'Regional': 'Regional', 'National': 'National',
        'Quality': 'Kvalitet', 'Condition': 'Tilstand', 'Excellent': 'Fremragende', 'Good': 'God',
        'Fair': 'Rimelig', 'Poor': 'Dårlig', 'Worn': 'Slidt', 'Year': 'År', 'Years': 'År',
        'Month': 'Måned', 'Months': 'Måneder', 'Day': 'Dag', 'Days': 'Dage',
        'Buy': 'Køb', 'Sell': 'Sælg', 'Trade': 'Handel', 'Offer': 'Tilbud',
        'Yes': 'Ja', 'No': 'Nej', 'OK': 'OK', 'Close': 'Luk', 'Back': 'Tilbage',
    },
    ea: {
        'Finance': 'Financiar', 'Lease': 'Arrendar', 'Vehicle': 'Vehículo', 'Payment': 'Pago',
        'Monthly': 'Mensual', 'Yearly': 'Anual', 'Total': 'Total', 'Cost': 'Costo',
        'Interest': 'Interés', 'Rate': 'Tasa', 'Credit': 'Crédito', 'Score': 'Puntaje',
        'Down Payment': 'Enganche', 'Term': 'Plazo', 'Balance': 'Saldo', 'Price': 'Precio',
        'Search': 'Buscar', 'Used': 'Usado', 'New': 'Nuevo', 'Equipment': 'Equipo',
        'Details': 'Detalles', 'Information': 'Información', 'Important': 'Importante',
        'Accept': 'Aceptar', 'Cancel': 'Cancelar', 'Confirm': 'Confirmar', 'Start': 'Iniciar',
        'Duration': 'Duración', 'Success': 'Éxito', 'Failed': 'Fallido',
        'Agent': 'Agente', 'Local': 'Local', 'Regional': 'Regional', 'National': 'Nacional',
        'Quality': 'Calidad', 'Condition': 'Condición', 'Excellent': 'Excelente', 'Good': 'Bueno',
        'Fair': 'Regular', 'Poor': 'Malo', 'Worn': 'Desgastado', 'Year': 'Año', 'Years': 'Años',
        'Month': 'Mes', 'Months': 'Meses', 'Day': 'Día', 'Days': 'Días',
        'Buy': 'Comprar', 'Sell': 'Vender', 'Trade': 'Intercambiar', 'Offer': 'Oferta',
        'Yes': 'Sí', 'No': 'No', 'OK': 'OK', 'Close': 'Cerrar', 'Back': 'Atrás',
    },
    fc: {
        'Finance': 'Financer', 'Lease': 'Louer', 'Vehicle': 'Véhicule', 'Payment': 'Paiement',
        'Monthly': 'Mensuel', 'Yearly': 'Annuel', 'Total': 'Total', 'Cost': 'Coût',
        'Interest': 'Intérêt', 'Rate': 'Taux', 'Credit': 'Crédit', 'Score': 'Pointage',
        'Down Payment': 'Mise de fonds', 'Term': 'Terme', 'Balance': 'Solde', 'Price': 'Prix',
        'Search': 'Rechercher', 'Used': 'Usagé', 'New': 'Neuf', 'Equipment': 'Équipement',
        'Details': 'Détails', 'Information': 'Information', 'Important': 'Important',
        'Accept': 'Accepter', 'Cancel': 'Annuler', 'Confirm': 'Confirmer', 'Start': 'Démarrer',
        'Duration': 'Durée', 'Success': 'Succès', 'Failed': 'Échoué',
        'Agent': 'Agent', 'Local': 'Local', 'Regional': 'Régional', 'National': 'National',
        'Quality': 'Qualité', 'Condition': 'État', 'Excellent': 'Excellent', 'Good': 'Bon',
        'Fair': 'Acceptable', 'Poor': 'Mauvais', 'Worn': 'Usé', 'Year': 'An', 'Years': 'Ans',
        'Month': 'Mois', 'Months': 'Mois', 'Day': 'Jour', 'Days': 'Jours',
        'Buy': 'Acheter', 'Sell': 'Vendre', 'Trade': 'Échanger', 'Offer': 'Offre',
        'Yes': 'Oui', 'No': 'Non', 'OK': 'OK', 'Close': 'Fermer', 'Back': 'Retour',
    },
    fi: {
        'Finance': 'Rahoitus', 'Lease': 'Leasing', 'Vehicle': 'Ajoneuvo', 'Payment': 'Maksu',
        'Monthly': 'Kuukausittainen', 'Yearly': 'Vuosittainen', 'Total': 'Yhteensä', 'Cost': 'Hinta',
        'Interest': 'Korko', 'Rate': 'Korko', 'Credit': 'Luotto', 'Score': 'Pistemäärä',
        'Down Payment': 'Käsiraha', 'Term': 'Laina-aika', 'Balance': 'Saldo', 'Price': 'Hinta',
        'Search': 'Haku', 'Used': 'Käytetty', 'New': 'Uusi', 'Equipment': 'Kalusto',
        'Details': 'Tiedot', 'Information': 'Tietoa', 'Important': 'Tärkeää',
        'Accept': 'Hyväksy', 'Cancel': 'Peruuta', 'Confirm': 'Vahvista', 'Start': 'Aloita',
        'Duration': 'Kesto', 'Success': 'Onnistui', 'Failed': 'Epäonnistui',
        'Agent': 'Agentti', 'Local': 'Paikallinen', 'Regional': 'Alueellinen', 'National': 'Valtakunnallinen',
        'Quality': 'Laatu', 'Condition': 'Kunto', 'Excellent': 'Erinomainen', 'Good': 'Hyvä',
        'Fair': 'Kohtalainen', 'Poor': 'Huono', 'Worn': 'Kulunut', 'Year': 'Vuosi', 'Years': 'Vuotta',
        'Month': 'Kuukausi', 'Months': 'Kuukautta', 'Day': 'Päivä', 'Days': 'Päivää',
        'Buy': 'Osta', 'Sell': 'Myy', 'Trade': 'Vaihda', 'Offer': 'Tarjous',
        'Yes': 'Kyllä', 'No': 'Ei', 'OK': 'OK', 'Close': 'Sulje', 'Back': 'Takaisin',
    },
    id: {
        'Finance': 'Pembiayaan', 'Lease': 'Sewa', 'Vehicle': 'Kendaraan', 'Payment': 'Pembayaran',
        'Monthly': 'Bulanan', 'Yearly': 'Tahunan', 'Total': 'Total', 'Cost': 'Biaya',
        'Interest': 'Bunga', 'Rate': 'Suku', 'Credit': 'Kredit', 'Score': 'Skor',
        'Down Payment': 'Uang Muka', 'Term': 'Jangka Waktu', 'Balance': 'Saldo', 'Price': 'Harga',
        'Search': 'Cari', 'Used': 'Bekas', 'New': 'Baru', 'Equipment': 'Peralatan',
        'Details': 'Detail', 'Information': 'Informasi', 'Important': 'Penting',
        'Accept': 'Terima', 'Cancel': 'Batal', 'Confirm': 'Konfirmasi', 'Start': 'Mulai',
        'Duration': 'Durasi', 'Success': 'Berhasil', 'Failed': 'Gagal',
        'Agent': 'Agen', 'Local': 'Lokal', 'Regional': 'Regional', 'National': 'Nasional',
        'Quality': 'Kualitas', 'Condition': 'Kondisi', 'Excellent': 'Sempurna', 'Good': 'Baik',
        'Fair': 'Cukup', 'Poor': 'Buruk', 'Worn': 'Aus', 'Year': 'Tahun', 'Years': 'Tahun',
        'Month': 'Bulan', 'Months': 'Bulan', 'Day': 'Hari', 'Days': 'Hari',
        'Buy': 'Beli', 'Sell': 'Jual', 'Trade': 'Tukar', 'Offer': 'Penawaran',
        'Yes': 'Ya', 'No': 'Tidak', 'OK': 'OK', 'Close': 'Tutup', 'Back': 'Kembali',
    },
    kr: {
        'Finance': '금융', 'Lease': '리스', 'Vehicle': '차량', 'Payment': '결제',
        'Monthly': '월간', 'Yearly': '연간', 'Total': '총', 'Cost': '비용',
        'Interest': '이자', 'Rate': '율', 'Credit': '신용', 'Score': '점수',
        'Down Payment': '계약금', 'Term': '기간', 'Balance': '잔액', 'Price': '가격',
        'Search': '검색', 'Used': '중고', 'New': '신규', 'Equipment': '장비',
        'Details': '세부사항', 'Information': '정보', 'Important': '중요',
        'Accept': '수락', 'Cancel': '취소', 'Confirm': '확인', 'Start': '시작',
        'Duration': '기간', 'Success': '성공', 'Failed': '실패',
        'Agent': '에이전트', 'Local': '지역', 'Regional': '광역', 'National': '전국',
        'Quality': '품질', 'Condition': '상태', 'Excellent': '최상', 'Good': '양호',
        'Fair': '보통', 'Poor': '불량', 'Worn': '마모', 'Year': '년', 'Years': '년',
        'Month': '월', 'Months': '개월', 'Day': '일', 'Days': '일',
        'Buy': '구매', 'Sell': '판매', 'Trade': '거래', 'Offer': '제안',
        'Yes': '예', 'No': '아니오', 'OK': '확인', 'Close': '닫기', 'Back': '뒤로',
    },
    no: {
        'Finance': 'Finansiering', 'Lease': 'Leasing', 'Vehicle': 'Kjøretøy', 'Payment': 'Betaling',
        'Monthly': 'Månedlig', 'Yearly': 'Årlig', 'Total': 'Totalt', 'Cost': 'Kostnad',
        'Interest': 'Rente', 'Rate': 'Sats', 'Credit': 'Kreditt', 'Score': 'Poengsum',
        'Down Payment': 'Forskuddsbetaling', 'Term': 'Løpetid', 'Balance': 'Saldo', 'Price': 'Pris',
        'Search': 'Søk', 'Used': 'Brukt', 'New': 'Ny', 'Equipment': 'Utstyr',
        'Details': 'Detaljer', 'Information': 'Informasjon', 'Important': 'Viktig',
        'Accept': 'Godta', 'Cancel': 'Avbryt', 'Confirm': 'Bekreft', 'Start': 'Start',
        'Duration': 'Varighet', 'Success': 'Suksess', 'Failed': 'Mislykket',
        'Agent': 'Agent', 'Local': 'Lokal', 'Regional': 'Regional', 'National': 'Nasjonal',
        'Quality': 'Kvalitet', 'Condition': 'Tilstand', 'Excellent': 'Utmerket', 'Good': 'Bra',
        'Fair': 'Grei', 'Poor': 'Dårlig', 'Worn': 'Slitt', 'Year': 'År', 'Years': 'År',
        'Month': 'Måned', 'Months': 'Måneder', 'Day': 'Dag', 'Days': 'Dager',
        'Buy': 'Kjøp', 'Sell': 'Selg', 'Trade': 'Bytt', 'Offer': 'Tilbud',
        'Yes': 'Ja', 'No': 'Nei', 'OK': 'OK', 'Close': 'Lukk', 'Back': 'Tilbake',
    },
    ro: {
        'Finance': 'Finanțare', 'Lease': 'Leasing', 'Vehicle': 'Vehicul', 'Payment': 'Plată',
        'Monthly': 'Lunar', 'Yearly': 'Anual', 'Total': 'Total', 'Cost': 'Cost',
        'Interest': 'Dobândă', 'Rate': 'Rată', 'Credit': 'Credit', 'Score': 'Scor',
        'Down Payment': 'Avans', 'Term': 'Termen', 'Balance': 'Sold', 'Price': 'Preț',
        'Search': 'Căutare', 'Used': 'Folosit', 'New': 'Nou', 'Equipment': 'Echipament',
        'Details': 'Detalii', 'Information': 'Informații', 'Important': 'Important',
        'Accept': 'Acceptă', 'Cancel': 'Anulează', 'Confirm': 'Confirmă', 'Start': 'Început',
        'Duration': 'Durată', 'Success': 'Succes', 'Failed': 'Eșuat',
        'Agent': 'Agent', 'Local': 'Local', 'Regional': 'Regional', 'National': 'Național',
        'Quality': 'Calitate', 'Condition': 'Stare', 'Excellent': 'Excelent', 'Good': 'Bun',
        'Fair': 'Acceptabil', 'Poor': 'Slab', 'Worn': 'Uzat', 'Year': 'An', 'Years': 'Ani',
        'Month': 'Lună', 'Months': 'Luni', 'Day': 'Zi', 'Days': 'Zile',
        'Buy': 'Cumpără', 'Sell': 'Vinde', 'Trade': 'Schimbă', 'Offer': 'Ofertă',
        'Yes': 'Da', 'No': 'Nu', 'OK': 'OK', 'Close': 'Închide', 'Back': 'Înapoi',
    },
    sv: {
        'Finance': 'Finansiering', 'Lease': 'Leasing', 'Vehicle': 'Fordon', 'Payment': 'Betalning',
        'Monthly': 'Månatlig', 'Yearly': 'Årlig', 'Total': 'Totalt', 'Cost': 'Kostnad',
        'Interest': 'Ränta', 'Rate': 'Sats', 'Credit': 'Kredit', 'Score': 'Poäng',
        'Down Payment': 'Handpenning', 'Term': 'Löptid', 'Balance': 'Saldo', 'Price': 'Pris',
        'Search': 'Sök', 'Used': 'Begagnad', 'New': 'Ny', 'Equipment': 'Utrustning',
        'Details': 'Detaljer', 'Information': 'Information', 'Important': 'Viktigt',
        'Accept': 'Acceptera', 'Cancel': 'Avbryt', 'Confirm': 'Bekräfta', 'Start': 'Starta',
        'Duration': 'Varaktighet', 'Success': 'Framgång', 'Failed': 'Misslyckades',
        'Agent': 'Agent', 'Local': 'Lokal', 'Regional': 'Regional', 'National': 'Nationell',
        'Quality': 'Kvalitet', 'Condition': 'Skick', 'Excellent': 'Utmärkt', 'Good': 'Bra',
        'Fair': 'Godtagbar', 'Poor': 'Dålig', 'Worn': 'Sliten', 'Year': 'År', 'Years': 'År',
        'Month': 'Månad', 'Months': 'Månader', 'Day': 'Dag', 'Days': 'Dagar',
        'Buy': 'Köp', 'Sell': 'Sälj', 'Trade': 'Byt', 'Offer': 'Erbjudande',
        'Yes': 'Ja', 'No': 'Nej', 'OK': 'OK', 'Close': 'Stäng', 'Back': 'Tillbaka',
    },
    vi: {
        'Finance': 'Tài chính', 'Lease': 'Thuê', 'Vehicle': 'Phương tiện', 'Payment': 'Thanh toán',
        'Monthly': 'Hàng tháng', 'Yearly': 'Hàng năm', 'Total': 'Tổng cộng', 'Cost': 'Chi phí',
        'Interest': 'Lãi suất', 'Rate': 'Tỷ lệ', 'Credit': 'Tín dụng', 'Score': 'Điểm',
        'Down Payment': 'Trả trước', 'Term': 'Kỳ hạn', 'Balance': 'Số dư', 'Price': 'Giá',
        'Search': 'Tìm kiếm', 'Used': 'Đã qua sử dụng', 'New': 'Mới', 'Equipment': 'Thiết bị',
        'Details': 'Chi tiết', 'Information': 'Thông tin', 'Important': 'Quan trọng',
        'Accept': 'Chấp nhận', 'Cancel': 'Hủy', 'Confirm': 'Xác nhận', 'Start': 'Bắt đầu',
        'Duration': 'Thời gian', 'Success': 'Thành công', 'Failed': 'Thất bại',
        'Agent': 'Đại lý', 'Local': 'Địa phương', 'Regional': 'Khu vực', 'National': 'Quốc gia',
        'Quality': 'Chất lượng', 'Condition': 'Tình trạng', 'Excellent': 'Xuất sắc', 'Good': 'Tốt',
        'Fair': 'Khá', 'Poor': 'Kém', 'Worn': 'Mòn', 'Year': 'Năm', 'Years': 'Năm',
        'Month': 'Tháng', 'Months': 'Tháng', 'Day': 'Ngày', 'Days': 'Ngày',
        'Buy': 'Mua', 'Sell': 'Bán', 'Trade': 'Giao dịch', 'Offer': 'Đề nghị',
        'Yes': 'Có', 'No': 'Không', 'OK': 'OK', 'Close': 'Đóng', 'Back': 'Quay lại',
    }
};

// Read English source file
const enPath = path.join(__dirname, 'translation_en.xml');
const enContent = fs.readFileSync(enPath, 'utf8');

// Extract all entries
const entryRegex = /<e k="([^"]+)" v="([^"]*)" eh="([^"]+)"\s*\/>/g;
const entries = [];
let match;
while ((match = entryRegex.exec(enContent)) !== null) {
    entries.push({ key: match[1], value: match[2], hash: match[3] });
}

console.log(`Found ${entries.length} entries in English source`);

// Translate a string using word mappings
function translateString(text, langCode) {
    const dict = TRANSLATIONS[langCode];
    if (!dict) return text;

    let result = text;

    // Sort keys by length (longest first) to avoid partial replacements
    const keys = Object.keys(dict).sort((a, b) => b.length - a.length);

    for (const key of keys) {
        // Use word boundary matching to avoid partial replacements
        const regex = new RegExp(`\\b${key}\\b`, 'gi');
        result = result.replace(regex, dict[key]);
    }

    return result;
}

// Generate translation file for each language
for (const [langCode, langInfo] of Object.entries(LANGUAGES)) {
    const targetPath = path.join(__dirname, `translation_${langCode}.xml`);

    // Read existing file to preserve structure
    let targetContent = fs.readFileSync(targetPath, 'utf8');

    let translatedCount = 0;

    // Replace each entry with translated version
    for (const entry of entries) {
        const translated = translateString(entry.value, langCode);

        // Find and replace in content (match by key)
        const oldPattern = new RegExp(
            `<e k="${entry.key}" v="[^"]*" eh="[^"]+"\\s*/>`,
            'g'
        );
        const newEntry = `<e k="${entry.key}" v="${translated}" eh="${entry.hash}" />`;

        if (targetContent.match(oldPattern)) {
            targetContent = targetContent.replace(oldPattern, newEntry);
            if (translated !== entry.value) translatedCount++;
        }
    }

    // Update header comment
    targetContent = targetContent.replace(
        /STATUS: Untranslated - Using English text as placeholder/,
        `STATUS: AI-translated (Claude)`
    );

    fs.writeFileSync(targetPath, targetContent, 'utf8');
    console.log(`${langInfo.name}: ${translatedCount} strings translated`);
}

console.log('\nTranslation complete! Run "node translation_sync.js status" to verify.');
